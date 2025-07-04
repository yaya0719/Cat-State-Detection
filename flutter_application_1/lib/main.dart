import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:grpc/grpc.dart';
import 'generated/image_stream.pbgrpc.dart';

class ServerConfig {
  static String serverIp = '192.168.0.30'; // 預設 IP
}

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '貓咪行為辨識系統',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainMenuPage(),
    );
  }
}

class MainMenuPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景圖片
          Image.asset('assets/background.jpg', fit: BoxFit.cover),
          // 前景內容
          Column(
            children: [
              const SizedBox(height: 80), // 頂部留白
              // 標題
              Text(
                '貓咪行為辨識系統',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              Spacer(), // 推按鈕到底
              // 按鈕區
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Column(
                  children: [
                    _buildButton(context, '開始', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CameraGrpcStreamPage(),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    _buildButton(context, '設定', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SettingsPage()),
                      );
                    }),
                    const SizedBox(height: 20),
                    _buildButton(
                      context,
                      '退出',
                      () => SystemNavigator.pop(),
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    String label,
    VoidCallback onPressed, {
    Color color = Colors.blue,
  }) {
    return SizedBox(
      width: 250,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: color),
        child: Text(label, style: TextStyle(fontSize: 18)),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ipController.text = ServerConfig.serverIp;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/background.jpg', fit: BoxFit.cover),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              const Text(
                '伺服器設定',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'gRPC 伺服器 IP 地址',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 40, left: 40, right: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ServerConfig.serverIp = _ipController.text;
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('儲存', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('返回', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 🎥 原始串流頁面（不變）
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
      ServerConfig.serverIp,
      port: 50051,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _stub = ImageStreamServiceClient(_channel);
    _grpcImageStreamController = StreamController<ImageRequest>();
    _imageRequestStream = _grpcImageStreamController.stream;

    _stub.streamImages(_imageRequestStream).listen((response) {
      final imageBytes = Uint8List.fromList(response.image);
      if (imageBytes.isEmpty) return;
      setState(() {
        _currentImage = imageBytes;
        _lastImage = imageBytes;
      });
    });
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(_cameras!.first, ResolutionPreset.low);
    await _controller!.initialize();
    setState(() {});
  }

  Future<void> _startStreaming() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isStreaming)
      return;
    await _controller!.startImageStream((CameraImage image) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastSentTimestamp < 40) return;
      _lastSentTimestamp = now;

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
      body: Column(
        children: [
          Expanded(
            child: Center(
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 狀態提示按鈕（暫不實作功能）
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: 狀態提示功能待實作
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('狀態提示', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 20),
                // 返回按鈕
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('返回', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
