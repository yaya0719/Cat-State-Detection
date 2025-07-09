import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:grpc/grpc.dart';
import 'package:http/http.dart' as http;
import 'generated/image_stream.pbgrpc.dart';

class ServerConfig {
  static String serverIp = '192.168.0.30'; // 預設 IP
  static String currentUser = 'default_user'; // 預設用戶名
  static String get httpApiUrl =>
      'http://$serverIp:5000/api'; // HTTP API 基礎 URL
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
                    _buildButton(context, '用戶設定', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => UserSettingsPage()),
                      );
                    }),
                    const SizedBox(height: 20),
                    _buildButton(context, '分類統計', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StatsPage()),
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
  final TextEditingController _userController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ipController.text = ServerConfig.serverIp;
    _userController.text = ServerConfig.currentUser;
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
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: TextField(
                  controller: _userController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: '用戶名',
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
                          ServerConfig.currentUser = _userController.text;
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

    // 建立 gRPC 呼叫時傳遞 user_id 到 metadata
    final callOptions = CallOptions(
      metadata: {'user-id': ServerConfig.currentUser},
    );

    _stub.streamImages(_imageRequestStream, options: callOptions).listen((
      response,
    ) {
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
                // 查看統計按鈕
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StatsPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('查看統計', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 15),
                // 狀態提示按鈕（保持原有功能）
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // 顯示目前用戶資訊
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('目前狀態'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('用戶: ${ServerConfig.currentUser}'),
                                  Text('伺服器: ${ServerConfig.serverIp}:50051'),
                                  Text('串流狀態: ${_isStreaming ? "進行中" : "已停止"}'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('確定'),
                                ),
                              ],
                            ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('狀態提示', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 15),
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

// 用戶設定頁面
class UserSettingsPage extends StatefulWidget {
  @override
  _UserSettingsPageState createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final TextEditingController _userController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userController.text = ServerConfig.currentUser;
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
                '用戶設定',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '目前用戶: ${ServerConfig.currentUser}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _userController,
                        decoration: const InputDecoration(
                          labelText: '輸入用戶名稱',
                          hintText: '例如: 小明、user123',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        '不同用戶的分類記錄會分開儲存',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
                          final newUser = _userController.text.trim();
                          if (newUser.isNotEmpty) {
                            ServerConfig.currentUser = newUser;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('用戶已切換為: $newUser'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
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
                          backgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('取消', style: TextStyle(fontSize: 16)),
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

// 分類統計頁面
class StatsPage extends StatefulWidget {
  @override
  _StatsPageState createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  Map<String, dynamic>? _userStats;
  bool _isLoading = true;
  String? _errorMessage;

  // 分類中文名稱對應
  final Map<String, String> _categoryNames = {
    'eating': '進食',
    'licking': '舔毛',
    'relex': '放鬆',
    'toilet': '如廁',
  };

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url =
          '${ServerConfig.httpApiUrl}/stats/${ServerConfig.currentUser}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userStats = data['stats'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'HTTP ${response.statusCode}: 無法載入統計資料';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '網路錯誤: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _resetStats() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('確認重置'),
            content: Text('確定要重置用戶 ${ServerConfig.currentUser} 的所有統計資料嗎？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('確定'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      final url =
          '${ServerConfig.httpApiUrl}/stats/${ServerConfig.currentUser}';
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('統計資料已重置'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUserStats(); // 重新載入
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重置失敗: HTTP ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('重置失敗: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildStatsContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('載入統計資料中...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 60),
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadUserStats,
              child: const Text('重新載入'),
            ),
          ],
        ),
      );
    }

    if (_userStats == null) {
      return const Center(
        child: Text(
          '沒有統計資料',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    final categories = _userStats!['categories'] as Map<String, dynamic>;
    final totalCount = _userStats!['total_count'] as int;
    final lastUpdate = _userStats!['last_update'] as String;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 用戶信息卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  ' ${ServerConfig.currentUser}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '總分類次數: $totalCount',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 分類統計列表
          Expanded(
            child: ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories.keys.elementAt(index);
                final count = categories[category] as int;

                final name = _categoryNames[category] ?? category;

                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // 最後更新時間
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '最後更新: ${_formatDateTime(lastUpdate)}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/background.jpg', fit: BoxFit.cover),
          Column(
            children: [
              const SizedBox(height: 80),
              const Text(
                '分類統計',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 4,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildStatsContent()),
              // 底部按鈕
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loadUserStats,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          '重新載入',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _resetStats,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('重置', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
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
