import 'package:flutter/material.dart';
import 'package:xp2p_sdk/src/log/logger.dart';

class TwoWayCallPage extends StatefulWidget {
  final String productId;
  final String deviceName;
  final String p2pInfo;

  const TwoWayCallPage({
    super.key,
    required this.productId,
    required this.deviceName,
    required this.p2pInfo,
  });

  @override
  State<TwoWayCallPage> createState() => _TwoWayCallPageState();
}

class _TwoWayCallPageState extends State<TwoWayCallPage> {
  @override
  void initState() {
    super.initState();
    Logger.i('进入IPC双向通话页面: productId=${widget.productId}, deviceName=${widget.deviceName}', 'TwoWayCall');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IPC双向通话'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.phone,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              'IPC双向通话功能',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              '设备: ${widget.deviceName}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // TODO: 实现双向通话功能
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('双向通话功能开发中...')),
                );
              },
              child: const Text('开始通话'),
            ),
          ],
        ),
      ),
    );
  }
}