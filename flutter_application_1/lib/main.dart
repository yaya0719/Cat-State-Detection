import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:grpc/grpc.dart';
import 'generated/image_stream.pbgrpc.dart';

void main() => runApp(MaterialApp(home: CameraGrpcStreamPage()));

class CameraGrpcStreamPage extends StatefulWidget {
  @override
  _CameraGrpcStreamPageState createState() => _CameraGrpcStreamPageState();
}

class _CameraGrpcStreamPageState extends State<CameraGrpcStreamPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isStreaming = false;
  late ClientChannel _channel;
  late ImageStreamServiceClient _stub;
  late Stream<ImageRequest> _imageRequestStream;
  late StreamController<ImageRequest> _grpcImageStreamController;

  bool _waitingResponse = false;
  int _lastSentTimestamp = 0;

  Uint8List? _currentImage;
  Uint8List? _lastImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _setupGrpc();
  }

  Future<void> _setupGrpc() async {
    _channel = ClientChannel(
      '192.168.0.30',
      port: 50051,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _stub = ImageStreamServiceClient(_channel);
    _grpcImageStreamController = StreamController<ImageRequest>();
    _imageRequestStream = _grpcImageStreamController.stream;

    _stub.streamImages(_imageRequestStream).listen((response) {
      final imageBytes = Uint8List.fromList(response.image);

      if (imageBytes.isEmpty) {
        print('⚠️ 收到空影像，忽略');
        _waitingResponse = false;
        return;
      }

      setState(() {
        _currentImage = imageBytes;
        _lastImage = imageBytes;
      });
      _waitingResponse = false;
    });
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(_cameras!.first, ResolutionPreset.low);
    await _controller!.initialize();
    setState(() {});
  }

  Future<void> _startStreaming() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isStreaming) return;

    await _controller!.startImageStream((CameraImage image) async {
      if (_waitingResponse) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastSentTimestamp < 40) return;
      _lastSentTimestamp = now;

      _waitingResponse = true;

      final jpegBytes = await _convertYUV420ToJpeg(image);
      final request = ImageRequest()..image = Uint8List.fromList(jpegBytes);
      _grpcImageStreamController.add(request);
    });

    setState(() => _isStreaming = true);
  }

  Future<void> _stopStreaming() async {
    if (_controller != null &&
        _controller!.value.isInitialized &&
        _isStreaming) {
      await _controller!.stopImageStream();
      setState(() => _isStreaming = false);
    }
  }

  Future<Uint8List> _convertYUV420ToJpeg(CameraImage image) async {
    final width = image.width;
    final height = image.height;
    final img.Image rgbImage = img.Image(width: width, height: height);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final rowStrideY = yPlane.bytesPerRow;
    final rowStrideUV = uPlane.bytesPerRow;
    final pixelStrideUV = uPlane.bytesPerPixel!;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final uvIndex = (rowStrideUV * (y ~/ 2)) + (x ~/ 2) * pixelStrideUV;
        final yIndex = y * rowStrideY + x;

        final yVal = yBytes[yIndex];
        final uVal = uBytes[uvIndex];
        final vVal = vBytes[uvIndex];

        final r = (yVal + 1.370705 * (vVal - 128)).clamp(0, 255).toInt();
        final g =
            (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128))
                .clamp(0, 255)
                .toInt();
        final b = (yVal + 1.732446 * (uVal - 128)).clamp(0, 255).toInt();

        rgbImage.setPixelRgb(x, y, r, g, b);
      }
    }

    return Uint8List.fromList(img.encodeJpg(rgbImage, quality: 20));
  }

  @override
  void dispose() {
    _controller?.dispose();
    _grpcImageStreamController.close();
    _channel.shutdown();
    super.dispose();
  }

  Widget _buildStreamView() {
    if (_currentImage != null && _currentImage!.isNotEmpty) {
      return Image.memory(_currentImage!, gaplessPlayback: true);
    } else if (_lastImage != null && _lastImage!.isNotEmpty) {
      return Image.memory(_lastImage!, gaplessPlayback: true);
    } else {
      return const Text("等待影像...");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('gRPC 相機串流')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_controller == null || !_controller!.value.isInitialized)
              CircularProgressIndicator()
            else if (_isStreaming)
              _buildStreamView()
            else
              const Text('按下按鈕開始串流'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isStreaming ? _stopStreaming : _startStreaming,
              child: Text(_isStreaming ? '停止串流' : '開始串流'),
            ),
          ],
        ),
      ),
    );
  }
}
