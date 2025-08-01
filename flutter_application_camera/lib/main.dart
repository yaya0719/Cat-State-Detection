import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:grpc/grpc.dart';
import 'package:image/image.dart' as img;
import 'generated/image_stream.pbgrpc.dart';  

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  final cameras = await availableCameras(); //向手機請求可用的相機
  runApp(MyApp(camera: cameras.first)); //first : 通常是後置相機
}

class MyApp extends StatelessWidget {
  final CameraDescription camera; 
  const MyApp({super.key, required this.camera});

  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera gRPC Stream',// 畫面最上面那行
      debugShowCheckedModeBanner: false,  //關閉debug banner
      home: CameraGrpcStreamPage(camera: camera), //指定主頁顯示相機與串流的頁面
    );
  }
}

// 主頁面：顯示相機畫面並提供串流按鈕
class CameraGrpcStreamPage extends StatefulWidget {
  final CameraDescription camera;
  const CameraGrpcStreamPage({super.key, required this.camera});

  @override
  State<CameraGrpcStreamPage> createState() => _CameraGrpcStreamPageState();// 控制頁面邏輯
}

// 控制頁面邏輯：處理相機初始化、串流控制與 gRPC 通訊
class _CameraGrpcStreamPageState extends State<CameraGrpcStreamPage> {
  CameraController? _controller; //控制相機的變數
  bool _isStreaming = false;

  // gRPC 相關變數
  late ClientChannel _channel;  // gRPC client端通道
  late ImageStreamServiceClient _stub;// gRPC 客戶端存根
  late StreamController<ImageRequest> _imageRequestStreamController;// 用來發送影像請求的 StreamController

  // 最後送出的影格時間戳（用來控制每 40ms 一張）
  int _lastSentTimestamp = 0;

  // 初始化相機與 gRPC 連線
  @override
  void initState() {
    super.initState();
    _initCamera();
    _initGrpc();
  }

  // 初始化相機
  Future<void> _initCamera() async {
    _controller = CameraController(widget.camera, ResolutionPreset.high);// 相機畫質設定
    await _controller!.initialize();// 等待相機初始化完成
    setState(() {}); // 相機顯示後要更新畫面
  }

  // 初始化 gRPC 連線(非同步)
  Future<void> _initGrpc() async {
    _channel = ClientChannel( //用來與 server 建立連線
      '192.168.1.107', // gRPC server IP（寫死）
      port: 50051,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _stub = ImageStreamServiceClient(_channel); // 來自.proto
    _imageRequestStreamController = StreamController<ImageRequest>();

    _stub.streamImages(//gRPC 定義的串流方法,把 image stream 傳給 server
      _imageRequestStreamController.stream,
      options: CallOptions(metadata: {'user-id': 'test-user'}),// 傳使用者資訊給 server（例如 user-id）
    );
  }

  Future<void> _startStreaming() async {
    // 如果相機未初始化或已經在串流中，則不進行任何操作
    if (_controller == null || !_controller!.value.isInitialized || _isStreaming) return;

    // 開始相機影像串流(格式是 YUV420)
    await _controller!.startImageStream((CameraImage image) async {
      // 40ms 控制：每 40 毫秒發送一張影像
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastSentTimestamp < 40) return;
      _lastSentTimestamp = now;

      final jpegBytes = await _convertYUV420ToJpeg(image);// 將 YUV420 格式的影像轉換為 JPEG
      final request = ImageRequest()..image = jpegBytes; //封裝成 gRPC request物件
      _imageRequestStreamController.add(request);// 將影像請求加入 StreamController
    });

    // 更新狀態為正在串流
    setState(() => _isStreaming = true);
  }

  Future<void> _stopStreaming() async {
    // 如果相機未初始化或在串流中，則關閉
    if (_controller != null && _controller!.value.isStreamingImages && _isStreaming) {
      await _controller!.stopImageStream();
      setState(() => _isStreaming = false);
    }
  }

  // 將 YUV420 格式的影像轉換為 JPEG 格式
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
        final g = (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128)).clamp(0, 255).toInt();
        final b = (yVal + 1.732446 * (uVal - 128)).clamp(0, 255).toInt();

        rgbImage.setPixelRgb(x, y, r, g, b);
      }
    }

    return Uint8List.fromList(img.encodeJpg(rgbImage, quality: 20));
  }

  // 清理資源：關閉相機與 gRPC 通道
  @override
  void dispose() {
    _controller?.dispose(); // 關閉相機控制器
    _imageRequestStreamController.close(); // 關閉影像請求的 StreamController
    _channel.shutdown();// 關閉 gRPC 通道
    super.dispose();// 呼叫父類別的 dispose 方法
  }

  // 建立畫面ui
  @override
  Widget build(BuildContext context) {
    return Scaffold(// Scaffold 是 Material Design 的基本佈局結構
      body: _controller != null && _controller!.value.isInitialized 
          ? Column(
              children: [
                Expanded(child: CameraPreview(_controller!)),//顯示相機畫面（來自 CameraController）
                Padding(
                  padding: const EdgeInsets.all(16),// 按鈕上下左右邊距
                  child: ElevatedButton(// 使用 ElevatedButton 來讓按鈕浮起
                    onPressed: _isStreaming ? _stopStreaming : _startStreaming, //點擊邏輯
                    child: Text(_isStreaming ? '停止串流' : '開始串流'),
                  ),
                )
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
