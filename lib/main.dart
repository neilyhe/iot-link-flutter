import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter/services.dart';
import 'video_stream_page.dart';
import 'two_way_call_page.dart';
import 'package:xp2p_sdk/src/log/logger.dart';

void main() {
  Logger.setLevel(LogLevel.debug);
  Logger.setConsoleOutput(true);
  // 初始化 media_kit
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Video',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/iot_video_logo.png',
              width: 128,
              height: 128,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const Text(
              'IoT Video',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '欢迎使用腾讯云IoT Video',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),

            Container(
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 1)),
              child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(300, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
                  ),
                  child: const Text(
                    'IoT Video (设备直连)',
                    style: TextStyle(fontSize: 16),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _productIdController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _p2pInfoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 设置默认值方便测试
    _productIdController.text = '';
    _deviceNameController.text = '';
    _p2pInfoController.text = '';
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _deviceNameController.dispose();
    _p2pInfoController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData != null && clipboardData.text != null) {
        final text = clipboardData.text!.trim();
        if (text.isNotEmpty) {
          final lines = text.split('\n');
          
          if (lines.length >= 3) {
            setState(() {
              _productIdController.text = lines[0].trim();
              _deviceNameController.text = lines[1].trim();
              _p2pInfoController.text = lines[2].trim();
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('粘贴成功')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('剪贴板内容格式不正确，需要三行数据')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('剪贴板为空')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('粘贴失败: $e')),
      );
    }
  }

  void _showFunctionSelection() {
    final productId = _productIdController.text.trim();
    final deviceName = _deviceNameController.text.trim();
    final p2pInfo = _p2pInfoController.text.trim();

    if (productId.isEmpty || deviceName.isEmpty || p2pInfo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写所有字段')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '选择功能',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.blue),
                title: const Text('预览'),
                subtitle: const Text('实时视频预览'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoStreamPage(
                        productId: productId,
                        deviceName: deviceName,
                        p2pInfo: p2pInfo,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.green),
                title: const Text('IPC双向通话'),
                subtitle: const Text('语音对讲功能'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TwoWayCallPage(
                        productId: productId,
                        deviceName: deviceName,
                        p2pInfo: p2pInfo,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备直连'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: _pasteFromClipboard,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.paste, size: 16),
              label: const Text('粘贴', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextField(
              controller: _productIdController,
              decoration: const InputDecoration(
                labelText: 'Product ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deviceNameController,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _p2pInfoController,
              decoration: const InputDecoration(
                labelText: 'P2P Info',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _showFunctionSelection,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('连接设备'),
            ),
          ],
        ),
      ),
    );
  }
}