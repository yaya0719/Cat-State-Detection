import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grpc/grpc.dart';
import 'package:http/http.dart' as http;
import 'generated/image_stream.pbgrpc.dart';

class ServerConfig {
  static String serverIp = '192.168.1.112'; // 預設 IP
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
                    _buildButton(context, '接收辨識結果', () {
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

// 🎥 影像接收與顯示頁面（接收處理過的影片）
class CameraGrpcStreamPage extends StatefulWidget {
  @override
  _CameraGrpcStreamPageState createState() => _CameraGrpcStreamPageState();
}

class _CameraGrpcStreamPageState extends State<CameraGrpcStreamPage> {
  bool _isReceiving = false;
  late ClientChannel _channel;
  late ImageStreamServiceClient _stub;
  StreamSubscription<ImageResponse>? _responseSubscription;

  Uint8List? _currentImage;
  Uint8List? _lastImage;
  String _detectionResult = "等待辨識結果...";

  @override
  void initState() {
    super.initState();
    _setupGrpc();
  }

  Future<void> _setupGrpc() async {
    _channel = ClientChannel(
      ServerConfig.serverIp,
      port: 50051,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _stub = ImageStreamServiceClient(_channel);
  }

  Future<void> _startReceiving() async {
    if (_isReceiving) return;

    try {
      // 使用 metadata 指定要觀看的用戶（相機的 user_id）
      final callOptions = CallOptions(
        metadata: {
          'user-id': ServerConfig.currentUser, // 要觀看的相機用戶 ID
        },
      );

      // 建立觀看請求
      final watchRequest = WatchRequest();

      // 呼叫新的 WatchStream 方法
      final responseStream = _stub.watchStream(
        watchRequest,
        options: callOptions,
      );

      _responseSubscription = responseStream.listen(
        (response) {
          if (response.image.isEmpty) {
            setState(() {
              _detectionResult = "連線正常 - ${DateTime.now().toString()}";
            });
            return;
          }

          final imageBytes = Uint8List.fromList(response.image);
          setState(() {
            _currentImage = imageBytes;
            _lastImage = imageBytes;
            _detectionResult =
                "已接收影像 (${DateTime.now().millisecondsSinceEpoch})";
          });
        },
        onError: (error) {
          print('gRPC 錯誤: $error');
          setState(() {
            _detectionResult = "連線錯誤: $error";
          });
        },
        onDone: () {
          print('gRPC 串流結束');
          setState(() {
            _isReceiving = false;
            _detectionResult = "串流已結束";
          });
        },
      );

      setState(() => _isReceiving = true);
    } catch (e) {
      print('啟動接收失敗: $e');
      setState(() {
        _detectionResult = "啟動失敗: $e";
      });
    }
  }

  Future<void> _stopReceiving() async {
    if (!_isReceiving) return;

    await _responseSubscription?.cancel();
    _responseSubscription = null;

    setState(() {
      _isReceiving = false;
      _detectionResult = "已停止接收";
    });
  }

  @override
  void dispose() {
    _responseSubscription?.cancel();
    _channel.shutdown();
    super.dispose();
  }

  Widget _buildStreamView() {
    if (_currentImage != null && _currentImage!.isNotEmpty) {
      return Column(
        children: [
          Expanded(
            child: Image.memory(
              _currentImage!,
              gaplessPlayback: true,
              fit: BoxFit.contain,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _detectionResult,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    } else if (_lastImage != null && _lastImage!.isNotEmpty) {
      return Column(
        children: [
          Expanded(
            child: Image.memory(
              _lastImage!,
              gaplessPlayback: true,
              fit: BoxFit.contain,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "顯示最後一張影像",
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    } else {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            "等待接收處理過的影像...",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('貓咪行為辨識結果'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: _buildStreamView()),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isReceiving ? _stopReceiving : _startReceiving,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isReceiving ? Colors.red : Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                    child: Text(
                      _isReceiving ? '停止接收' : '開始接收',
                      style: const TextStyle(fontSize: 18),
                    ),
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
                // 狀態提示按鈕
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // 顯示目前狀態資訊
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('系統狀態'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('用戶: ${ServerConfig.currentUser}'),
                                  Text('伺服器: ${ServerConfig.serverIp}:50051'),
                                  Text('接收狀態: ${_isReceiving ? "進行中" : "已停止"}'),
                                  Text('辨識結果: $_detectionResult'),
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
