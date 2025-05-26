import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_manager.dart';

class HeadphoneScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('蓝牙耳机管理'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Consumer<BluetoothManager>(
        builder: (context, bluetoothManager, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 连接状态卡片
                _buildConnectionCard(bluetoothManager),
                SizedBox(height: 16),
                
                // 电池状态卡片
                if (bluetoothManager.isConnected) ...[
                  _buildBatteryCard(bluetoothManager),
                  SizedBox(height: 16),
                ],
                
                // 设备扫描卡片
                _buildScanCard(bluetoothManager),
                SizedBox(height: 16),
                
                // 发现的设备列表
                _buildDeviceList(bluetoothManager),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionCard(BluetoothManager bluetoothManager) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (bluetoothManager.connectionState) {
      case BluetoothConnectionState.connected:
        statusColor = Colors.green;
        statusText = '已连接';
        statusIcon = Icons.bluetooth_connected;
        break;
      case BluetoothConnectionState.connecting:
        statusColor = Colors.orange;
        statusText = '连接中...';
        statusIcon = Icons.bluetooth_searching;
        break;
      case BluetoothConnectionState.disconnecting:
        statusColor = Colors.orange;
        statusText = '断开连接中...';
        statusIcon = Icons.bluetooth_disabled;
        break;
      default:
        statusColor = Colors.grey;
        statusText = '未连接';
        statusIcon = Icons.bluetooth;
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '连接状态',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (bluetoothManager.connectedDevice != null) ...[
              SizedBox(height: 12),
              Divider(),
              SizedBox(height: 8),
              Text(
                '设备信息',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text('设备名称: ${bluetoothManager.connectedDevice!.platformName}'),
              Text('设备ID: ${bluetoothManager.connectedDevice!.remoteId}'),
              SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => bluetoothManager.disconnect(),
                icon: Icon(Icons.bluetooth_disabled),
                label: Text('断开连接'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryCard(BluetoothManager bluetoothManager) {
    Color batteryColor;
    IconData batteryIcon;
    
    if (bluetoothManager.batteryLevel > 60) {
      batteryColor = Colors.green;
      batteryIcon = Icons.battery_full;
    } else if (bluetoothManager.batteryLevel > 30) {
      batteryColor = Colors.orange;
      batteryIcon = Icons.battery_3_bar;
    } else if (bluetoothManager.batteryLevel > 15) {
      batteryColor = Colors.red;
      batteryIcon = Icons.battery_2_bar;
    } else {
      batteryColor = Colors.red.shade700;
      batteryIcon = Icons.battery_1_bar;
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(batteryIcon, color: batteryColor, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '电池状态',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${bluetoothManager.batteryLevel}%',
                        style: TextStyle(
                          color: batteryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => bluetoothManager.refreshBatteryLevel(),
                  icon: Icon(Icons.refresh),
                  label: Text('刷新'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // 电池电量进度条
            LinearProgressIndicator(
              value: bluetoothManager.batteryLevel / 100.0,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
              minHeight: 8,
            ),
            SizedBox(height: 8),
            Text(
              _getBatteryStatusText(bluetoothManager.batteryLevel),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getBatteryStatusText(int batteryLevel) {
    if (batteryLevel > 80) return '电量充足';
    if (batteryLevel > 60) return '电量良好';
    if (batteryLevel > 30) return '电量适中';
    if (batteryLevel > 15) return '电量偏低';
    return '电量不足，请及时充电';
  }

  Widget _buildScanCard(BluetoothManager bluetoothManager) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  bluetoothManager.isScanning ? Icons.radar : Icons.search,
                  color: bluetoothManager.isScanning ? Colors.blue : Colors.grey,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '设备扫描',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        bluetoothManager.isScanning ? '正在扫描附近的蓝牙设备...' : '点击开始扫描蓝牙设备',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: bluetoothManager.isScanning
                        ? () => bluetoothManager.stopScan()
                        : () => bluetoothManager.startScan(),
                    icon: Icon(bluetoothManager.isScanning ? Icons.stop : Icons.search),
                    label: Text(bluetoothManager.isScanning ? '停止扫描' : '开始扫描'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bluetoothManager.isScanning ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (bluetoothManager.isScanning) ...[
              SizedBox(height: 12),
              LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(BluetoothManager bluetoothManager) {
    if (bluetoothManager.discoveredDevices.isEmpty) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.bluetooth_searching,
                size: 64,
                color: Colors.grey.shade400,
              ),
              SizedBox(height: 16),
              Text(
                '未发现设备',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '请确保蓝牙设备处于配对模式并点击扫描',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '发现的设备 (${bluetoothManager.discoveredDevices.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: bluetoothManager.discoveredDevices.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              BluetoothDevice device = bluetoothManager.discoveredDevices[index];
              bool isConnected = bluetoothManager.connectedDevice == device;
              
              return ListTile(
                leading: Icon(
                  _getDeviceIcon(device.platformName),
                  color: isConnected ? Colors.green : Colors.blue,
                  size: 32,
                ),
                title: Text(
                  device.platformName.isNotEmpty ? device.platformName : '未知设备',
                  style: TextStyle(
                    fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
                    color: isConnected ? Colors.green : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${device.remoteId}'),
                    if (isConnected)
                      Text(
                        '已连接',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                trailing: isConnected
                    ? Icon(Icons.check_circle, color: Colors.green)
                    : ElevatedButton(
                        onPressed: bluetoothManager.connectionState == BluetoothConnectionState.connecting
                            ? null
                            : () => _connectToDevice(context, bluetoothManager, device),
                        child: Text('连接'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                isThreeLine: isConnected,
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String deviceName) {
    String name = deviceName.toLowerCase();
    if (name.contains('headphone') || name.contains('耳机')) {
      return Icons.headphones;
    } else if (name.contains('speaker') || name.contains('音响')) {
      return Icons.speaker;
    } else if (name.contains('mouse') || name.contains('鼠标')) {
      return Icons.mouse;
    } else if (name.contains('keyboard') || name.contains('键盘')) {
      return Icons.keyboard;
    } else {
      return Icons.bluetooth;
    }
  }

  Future<void> _connectToDevice(BuildContext context, BluetoothManager bluetoothManager, BluetoothDevice device) async {
    // 显示连接进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在连接到 ${device.platformName}...'),
            ],
          ),
        );
      },
    );
        // 关闭进度对话框
   
    try {
         bool success = await bluetoothManager.connectToDevice(device);
          Navigator.of(context).pop();
          print("🔗连接成功 ${success.toString()}...");

      // 显示连接结果
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '连接成功!!!' : '连接失败，请重试'),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("link error ${e.toString()}");
    }

 
    
   
  }
}