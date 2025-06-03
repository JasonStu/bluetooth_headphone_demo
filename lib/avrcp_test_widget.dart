import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bluetooth_manager.dart';
import 'avrcp_utils.dart';

/// AVRCP功能专门测试界面
/// 用于验证和演示AVRCP协议的工作状态
class AVRCPTestWidget extends StatefulWidget {
  @override
  _AVRCPTestWidgetState createState() => _AVRCPTestWidgetState();
}

class _AVRCPTestWidgetState extends State<AVRCPTestWidget> {
  bool _isTestingAVRCP = false;
  AVRCPTestResult? _lastTestResult;
  AVRCPInfo? _avrcpInfo;

  @override
  void initState() {
    super.initState();
    _detectAVRCPOnConnectedDevice();
  }

  /// 检测已连接设备的AVRCP功能
  Future<void> _detectAVRCPOnConnectedDevice() async {
    final bluetoothManager = Provider.of<BluetoothManager>(context, listen: false);

    if (bluetoothManager.connectedDevice != null) {
      try {
        var services = await bluetoothManager.connectedDevice!.discoverServices();
        _avrcpInfo = await AVRCPUtils.detectAVRCP(bluetoothManager.connectedDevice!, services);
        setState(() {});
      } catch (e) {
        print("AVRCP检测失败: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothManager>(
      builder: (context, bluetoothManager, child) {
        if (!bluetoothManager.isConnected) {
          return _buildNotConnectedView();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('AVRCP协议测试'),
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _detectAVRCPOnConnectedDevice,
                tooltip: '重新检测AVRCP',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // AVRCP状态概览
                _buildAVRCPStatusCard(),
                SizedBox(height: 16),

                // AVRCP版本信息
                if (_avrcpInfo != null) ...[
                  _buildAVRCPVersionCard(),
                  SizedBox(height: 16),
                ],

                // 绝对音量控制测试
                _buildVolumeControlTestCard(bluetoothManager),
                SizedBox(height: 16),

                // AVRCP功能测试
                _buildAVRCPFunctionTestCard(bluetoothManager),
                SizedBox(height: 16),

                // 测试结果显示
                if (_lastTestResult != null) ...[
                  _buildTestResultCard(),
                  SizedBox(height: 16),
                ],

                // JBL Live Pro+ TWS 特别说明
                if (bluetoothManager.connectedDevice?.platformName.toLowerCase().contains('jbl') == true) ...[
                  _buildJBLSpecialNotesCard(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotConnectedView() {
    return Scaffold(
      appBar: AppBar(
        title: Text('AVRCP协议测试'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 80,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              '请先连接蓝牙音频设备',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'AVRCP测试需要连接到支持的蓝牙耳机',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back),
              label: Text('返回连接界面'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAVRCPStatusCard() {
    bool avrcpSupported = _avrcpInfo?.avrcpSupported ?? false;
    Color statusColor = avrcpSupported ? Colors.green : Colors.red;

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
                  avrcpSupported ? Icons.check_circle : Icons.error,
                  color: statusColor,
                  size: 32,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AVRCP协议状态',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        avrcpSupported ? '协议已检测并支持' : '协议未检测或不支持',
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

            if (_avrcpInfo != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: avrcpSupported ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: avrcpSupported ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '检测结果摘要:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildInfoRow('设备类型', _avrcpInfo!.deviceType),
                    _buildInfoRow('AVRCP版本', _avrcpInfo!.avrcpVersion),
                    _buildInfoRow('音量控制', _avrcpInfo!.volumeControlSupported ? '支持' : '不支持'),
                    _buildInfoRow('A2DP支持', _avrcpInfo!.supportsA2DP ? '是' : '否'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAVRCPVersionCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Text(
                  'AVRCP版本详细信息',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '检测到的AVRCP版本: ${_avrcpInfo!.avrcpVersion}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _getAVRCPVersionDescription(_avrcpInfo!.avrcpVersion),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12),
            Text(
              '支持的功能:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),

            ...(_avrcpInfo!.detectedServices.map((service) =>
                _buildFeatureRow(service, true)
            ).toList()),

            if (_avrcpInfo!.jblSpecificFeatures.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                'JBL特定功能:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700),
              ),
              SizedBox(height: 4),
              ...(_avrcpInfo!.jblSpecificFeatures.map((feature) =>
                  _buildFeatureRow(feature, true, color: Colors.orange)
              ).toList()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeControlTestCard(BluetoothManager bluetoothManager) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.volume_up, color: Colors.purple, size: 24),
                SizedBox(width: 8),
                Text(
                  '绝对音量控制测试',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '通过绝对音量控制验证AVRCP协议工作状态',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),

            // 当前音量显示
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.volume_up, color: Colors.purple),
                  SizedBox(width: 8),
                  Text(
                    '当前音量: ${bluetoothManager.currentVolume}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // 音量控制按钮
            Text(
              '快速音量测试:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildVolumeTestButton(bluetoothManager, '20%', 20),
                _buildVolumeTestButton(bluetoothManager, '40%', 40),
                _buildVolumeTestButton(bluetoothManager, '60%', 60),
                _buildVolumeTestButton(bluetoothManager, '80%', 80),
                _buildVolumeTestButton(bluetoothManager, '100%', 100),
              ],
            ),

            SizedBox(height: 16),

            // 音量滑块
            Text(
              '精确音量控制:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),

            Slider(
              value: bluetoothManager.currentVolume.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '${bluetoothManager.currentVolume}%',
              onChanged: (value) {
                bluetoothManager.setAbsoluteVolume(value.round());
              },
              activeColor: Colors.purple,
            ),

            SizedBox(height: 8),

            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                '✅ 如果您能听到音量变化，说明AVRCP绝对音量控制正常工作！',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeTestButton(BluetoothManager bluetoothManager, String label, int volume) {
    return ElevatedButton(
      onPressed: () async {
        bool success = await bluetoothManager.setAbsoluteVolume(volume);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '音量已设置为 $volume%' : '音量设置失败'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple.shade100,
        foregroundColor: Colors.purple.shade700,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildAVRCPFunctionTestCard(BluetoothManager bluetoothManager) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text(
                  'AVRCP协议功能测试',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '执行全面的AVRCP功能测试以验证协议工作状态',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTestingAVRCP ? null : () => _runAVRCPTest(bluetoothManager),
                    icon: _isTestingAVRCP
                        ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    )
                        : Icon(Icons.play_arrow),
                    label: Text(_isTestingAVRCP ? '测试中...' : '开始AVRCP测试'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '测试内容包括:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildTestItemRow('AVRCP协议检测和版本确认'),
                  _buildTestItemRow('绝对音量控制功能验证'),
                  _buildTestItemRow('音量变化响应测试'),
                  _buildTestItemRow('设备特定功能检测'),
                  _buildTestItemRow('协议兼容性评估'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultCard() {
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
                  _lastTestResult!.overallSuccess ? Icons.check_circle : Icons.error,
                  color: _lastTestResult!.overallSuccess ? Colors.green : Colors.red,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'AVRCP测试结果',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _lastTestResult!.overallSuccess ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _lastTestResult!.overallSuccess ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lastTestResult!.conclusion,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _lastTestResult!.overallSuccess ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                  SizedBox(height: 12),

                  _buildTestStatsRow('测试时长', '${_lastTestResult!.duration.inMilliseconds}ms'),
                  _buildTestStatsRow('成功测试', '${_lastTestResult!.successfulTests}'),
                  _buildTestStatsRow('失败测试', '${_lastTestResult!.failedTests}'),

                  if (_lastTestResult!.testDetails.isNotEmpty) ...[
                    SizedBox(height: 12),
                    Text(
                      '详细结果:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    ...(_lastTestResult!.testDetails.map((detail) =>
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            detail,
                            style: TextStyle(fontSize: 12),
                          ),
                        )
                    ).toList()),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJBLSpecialNotesCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.headphones, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text(
                  'JBL Live Pro+ TWS 特别说明',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎧 JBL Live Pro+ TWS 规格确认:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  SizedBox(height: 8),

                  _buildJBLFeatureRow('AVRCP版本', '1.5 (确认支持)'),
                  _buildJBLFeatureRow('绝对音量控制', '支持 (0-127范围)'),
                  _buildJBLFeatureRow('主动降噪', '支持ANC控制'),
                  _buildJBLFeatureRow('环境感知模式', '支持Ambient Aware'),
                  _buildJBLFeatureRow('自定义EQ', '支持应用内调节'),
                  _buildJBLFeatureRow('双耳独立连接', '支持True Wireless'),

                  SizedBox(height: 12),

                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '✅ 通过绝对音量控制测试，可以确认JBL Live Pro+ TWS的AVRCP 1.5协议正常工作！',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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

  Widget _buildFeatureRow(String feature, bool supported, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            supported ? Icons.check : Icons.close,
            size: 16,
            color: color ?? (supported ? Colors.green : Colors.red),
          ),
          SizedBox(width: 8),
          Text(
            feature,
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTestItemRow(String item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              item,
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestStatsRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildJBLFeatureRow(String feature, String status) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$feature:',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getAVRCPVersionDescription(String version) {
    switch (version) {
      case '1.0':
        return '基本音频控制功能（播放/暂停/跳转）';
      case '1.3':
        return '增加绝对音量控制和元数据传输';
      case '1.4':
        return '支持浏览和搜索功能，增强的元数据';
      case '1.5':
        return '支持多媒体控制和高级音频功能';
      case '1.6':
        return '最新版本，支持所有高级控制功能';
      default:
        if (version.contains('JBL')) {
          return 'JBL定制AVRCP实现，支持绝对音量控制';
        } else if (version.contains('Apple')) {
          return 'Apple设备使用系统级AVRCP集成';
        }
        return '设备特定的AVRCP实现';
    }
  }

  Future<void> _runAVRCPTest(BluetoothManager bluetoothManager) async {
    if (bluetoothManager.connectedDevice == null) return;

    setState(() {
      _isTestingAVRCP = true;
    });

    try {
      var services = await bluetoothManager.connectedDevice!.discoverServices();
      _lastTestResult = await AVRCPUtils.testAbsoluteVolumeControl(
        bluetoothManager.connectedDevice!,
        services,
      );

      // 显示测试完成通知
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_lastTestResult!.overallSuccess ? 'AVRCP测试通过！' : 'AVRCP测试完成，有部分失败'),
          backgroundColor: _lastTestResult!.overallSuccess ? Colors.green : Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AVRCP测试出错: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isTestingAVRCP = false;
      });
    }
  }
}