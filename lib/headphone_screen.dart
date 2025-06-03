import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_manager.dart';
import 'battery_calibration.dart';

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
                  _buildBatteryCard(context, bluetoothManager),
                  SizedBox(height: 16),
                ],

                // 设备扫描卡片
                _buildScanCard(bluetoothManager),
                SizedBox(height: 16),

                // 发现的设备列表
                _buildDeviceList(context, bluetoothManager),
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

  Widget _buildBatteryCard(BuildContext context, BluetoothManager bluetoothManager) {
    Color batteryColor;
    IconData batteryIcon;
    String batteryText;

    if (bluetoothManager.batteryLevel == -1) {
      // 不支持电池读取
      batteryColor = Colors.grey;
      batteryIcon = Icons.battery_unknown;
      batteryText = "不支持";
    } else if (bluetoothManager.batteryLevel == 0 && !bluetoothManager.batterySupported) {
      // 检测中或获取失败
      batteryColor = Colors.orange;
      batteryIcon = Icons.battery_unknown;
      batteryText = "检测中...";
    } else if (bluetoothManager.batteryLevel > 60) {
      batteryColor = Colors.green;
      batteryIcon = Icons.battery_full;
      batteryText = "${bluetoothManager.batteryLevel}%";
    } else if (bluetoothManager.batteryLevel > 30) {
      batteryColor = Colors.orange;
      batteryIcon = Icons.battery_3_bar;
      batteryText = "${bluetoothManager.batteryLevel}%";
    } else if (bluetoothManager.batteryLevel > 15) {
      batteryColor = Colors.red;
      batteryIcon = Icons.battery_2_bar;
      batteryText = "${bluetoothManager.batteryLevel}%";
    } else if (bluetoothManager.batteryLevel >= 0) {
      batteryColor = Colors.red.shade700;
      batteryIcon = Icons.battery_1_bar;
      batteryText = "${bluetoothManager.batteryLevel}%";
    } else {
      batteryColor = Colors.grey;
      batteryIcon = Icons.battery_unknown;
      batteryText = "未知";
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
                      Row(
                        children: [
                          Text(
                            batteryText,
                            style: TextStyle(
                              color: batteryColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (bluetoothManager.batteryLevel != bluetoothManager.rawBatteryValue &&
                              bluetoothManager.rawBatteryValue > 0) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '原始:${bluetoothManager.rawBatteryValue}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => bluetoothManager.refreshBatteryLevel(),
                      icon: Icon(Icons.refresh, size: 16),
                      label: Text('刷新', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size(0, 32),
                      ),
                    ),
                    SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: () => _showBatteryDetails(context, bluetoothManager),
                      icon: Icon(Icons.info_outline, size: 16),
                      label: Text('详情', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size(0, 32),
                      ),
                    ),
                    SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: () => _showCalibrationDialog(context, bluetoothManager),
                      icon: Icon(Icons.tune, size: 16),
                      label: Text('校准', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size(0, 32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),

            // 电池电量进度条（仅在有有效电量时显示）
            if (bluetoothManager.batteryLevel >= 0) ...[
              LinearProgressIndicator(
                value: bluetoothManager.batteryLevel / 100.0,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
                minHeight: 8,
              ),
              SizedBox(height: 8),
            ],

            // 显示电池信息来源和校准信息
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '数据来源: ${bluetoothManager.batterySource}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (bluetoothManager.batteryLevel != bluetoothManager.rawBatteryValue &&
                      bluetoothManager.rawBatteryValue > 0) ...[
                    SizedBox(height: 4),
                    Text(
                      '已应用设备校准 (原始值: ${bluetoothManager.rawBatteryValue}%)',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: 8),
            Text(
              _getBatteryStatusText(bluetoothManager.batteryLevel),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),

            // 如果是AirPods，显示特殊说明
            if (bluetoothManager.connectedDevice?.platformName.toLowerCase().contains('airpods') == true) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AirPods 电量读取已优化，如仍有差异，可通过 iOS 控制中心查看系统电量。',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getBatteryStatusText(int batteryLevel) {
    if (batteryLevel == -1) return '此设备不支持电池电量读取';
    if (batteryLevel == 0) return '正在检测电池状态...';
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
                        bluetoothManager.isScanning
                            ? '正在扫描附近的蓝牙设备...'
                            : '点击开始扫描蓝牙设备',
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
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blue.shade600),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '增强搜索：15秒深度扫描，可发现更多设备（包括未命名设备）',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoRow(String label, String value) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
 

  void _showDeviceInfoDialog(BuildContext context, BluetoothDevice device) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('${device.platformName} 详细信息'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDeviceInfoRow('设备名称', device.platformName.isNotEmpty
                  ? device.platformName
                  : '未知设备'),
              _buildDeviceInfoRow('设备ID', device.remoteId.toString()),
              _buildDeviceInfoRow('是否已连接', device.isConnected ? '是' : '否'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text('关闭'),
          ),
        ],
      );
    },
  );
}

  Widget _buildDeviceList(BuildContext context, BluetoothManager bluetoothManager) {
    if (bluetoothManager.discoveredDevices.isEmpty) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                bluetoothManager.isScanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
                size: 64,
                color: Colors.grey.shade400,
              ),
              SizedBox(height: 16),
              Text(
                bluetoothManager.isScanning ? '正在搜索设备...' : '未发现设备',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                bluetoothManager.isScanning
                    ? '请稍候，正在搜索附近的蓝牙设备'
                    : '请确保蓝牙设备处于配对模式并点击扫描',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
              if (!bluetoothManager.isScanning) ...[
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => bluetoothManager.startScan(),
                  icon: Icon(Icons.refresh),
                  label: Text('重新扫描'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '发现的设备 (${bluetoothManager.discoveredDevices.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!bluetoothManager.isScanning) ...[
                  IconButton(
                    onPressed: () => bluetoothManager.startScan(),
                    icon: Icon(Icons.refresh),
                    tooltip: '重新扫描',
                  ),
                ] else ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
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
              String displayName = bluetoothManager.getDeviceDisplayName(device);

              return ListTile(
                leading: Icon(
                  _getDeviceIcon(displayName),
                  color: isConnected ? Colors.green : Colors.blue,
                  size: 32,
                ),
                title: Text(
                  displayName,
                  style: TextStyle(
                    fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
                    color: isConnected ? Colors.green : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID: ${device.remoteId.toString().substring(0, 8)}...',
                      style: TextStyle(fontSize: 11),
                    ),
                    if (isConnected) ...[
                      Text(
                        '已连接',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ] else ...[
                      Text(
                        _getDeviceTypeDescription(displayName),
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: isConnected
                    ? Icon(Icons.check_circle, color: Colors.green)
                    : ElevatedButton(
                  onPressed: bluetoothManager.connectionState == BluetoothConnectionState.connecting
                      ? null
                      : () => _connectToDevice(context, bluetoothManager, device),
                  child: Text('连接', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size(0, 32),
                  ),
                ),
                onTap: () => _showDeviceInfoDialog(context, device)
              );
            },
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '提示：某些设备可能显示为"未知设备"，这是正常现象。请根据设备类型图标判断。',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

  // 获取设备类型描述
  String _getDeviceTypeDescription(String deviceName) {
    String name = deviceName.toLowerCase();
    if (name.contains('airpods') || name.contains('beats')) {
      return 'Apple 音频设备';
    } else if (name.contains('headphone') || name.contains('耳机')) {
      return '耳机设备';
    } else if (name.contains('speaker') || name.contains('音响')) {
      return '音响设备';
    } else if (name.contains('未知')) {
      return '蓝牙设备';
    } else {
      return '蓝牙设备';
    }
  }

  // 显示电池详细信息对话框
  void _showBatteryDetails(BuildContext context, BluetoothManager bluetoothManager) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('电池详细信息'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('显示电量', '${bluetoothManager.batteryLevel}%'),
              _buildDetailRow('原始数值', '${bluetoothManager.rawBatteryValue}%'),
              _buildDetailRow('校准电量', '${bluetoothManager.calibratedBatteryLevel.toStringAsFixed(1)}%'),
              _buildDetailRow('数据来源', bluetoothManager.batterySource),
              _buildDetailRow('设备名称', bluetoothManager.connectedDevice?.platformName ?? '未知'),
              SizedBox(height: 12),
              Text(
                '说明：',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                '• 显示电量：经过校准和平滑处理的最终值\n'
                    '• 原始数值：设备直接返回的电量值\n'
                    '• 校准电量：根据设备特性调整后的精确值\n'
                    '• 不同品牌设备的电量报告方式可能有差异',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('关闭'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                bluetoothManager.refreshBatteryLevel();
              },
              child: Text('重新读取'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // 显示校准对话框
  void _showCalibrationDialog(BuildContext context, BluetoothManager bluetoothManager) {
    if (bluetoothManager.connectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请先连接设备')),
      );
      return;
    }

    BatteryCalibration.showCalibrationDialog(
      context,
      bluetoothManager.connectedDevice!.remoteId.toString(),
      bluetoothManager.connectedDevice!.platformName,
      bluetoothManager.batteryLevel,
          (newFactor) {
        // 重新读取电量以应用新的校准
        bluetoothManager.refreshBatteryLevel();
      },
    );
  }

  Future<void> _connectToDevice(BuildContext context, BluetoothManager bluetoothManager, BluetoothDevice device) async {
    bool? dialogResult;

    try {
      // 显示连接进度对话框，并等待连接完成
      dialogResult = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          // 在对话框内部执行连接操作
          _performConnection(dialogContext, bluetoothManager, device);

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

      // 检查主页面context是否仍然有效再显示SnackBar
      if (context.mounted && dialogResult != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dialogResult ? '连接成功!' : '连接失败，请重试'),
            backgroundColor: dialogResult ? Colors.green : Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Connection dialog error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接过程中出现错误'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // 执行实际的连接操作
  Future<void> _performConnection(BuildContext dialogContext, BluetoothManager bluetoothManager, BluetoothDevice device) async {
    try {
      bool success = await bluetoothManager.connectToDevice(device);

      // 安全地关闭对话框并返回结果
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop(success);
      }
    } catch (e) {
      print('Connection error: $e');
      // 安全地关闭对话框并返回失败结果
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop(false);
      }
    }
  }
}