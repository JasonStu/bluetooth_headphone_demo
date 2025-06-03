import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_manager.dart';
import 'headphone_screen.dart';
import 'avrcp_test_widget.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BluetoothManager(),
      child: MaterialApp(
        title: 'Bluetooth AVRCP Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          // 添加自定义主题
          appBarTheme: AppBarTheme(
            elevation: 2,
            centerTitle: true,
          ),
          // cardTheme: CardTheme(
          //   elevation: 4,
          //   margin: EdgeInsets.symmetric(vertical: 4),
          // ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        home: MainNavigationScreen(),
        debugShowCheckedModeBanner: false,
        routes: {
          '/headphone': (context) => HeadphoneScreen(),
          '/avrcp_test': (context) => AVRCPTestWidget(),
        },
      ),
    );
  }
}

/// 主导航界面
class MainNavigationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('蓝牙AVRCP演示应用'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Consumer<BluetoothManager>(
        builder: (context, bluetoothManager, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 应用介绍卡片
                _buildIntroCard(),
                SizedBox(height: 16),

                // 连接状态卡片
                _buildConnectionStatusCard(bluetoothManager),
                SizedBox(height: 16),

                // 功能导航卡片
                _buildNavigationCard(context, bluetoothManager),
                SizedBox(height: 16),

                // AVRCP验证说明卡片
                _buildAVRCPExplanationCard(),
                SizedBox(height: 16),

                // JBL Live Pro+ TWS 特别说明
                _buildJBLSpecialCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntroCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth_audio, color: Colors.blue, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '蓝牙AVRCP验证演示',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '证明AVRCP协议正常工作',
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
            Text(
              '本应用通过以下方式验证AVRCP (Audio/Video Remote Control Profile) 协议：',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            _buildFeaturePoint('🔍 自动检测AVRCP版本号'),
            _buildFeaturePoint('🎵 实现绝对音量控制功能'),
            _buildFeaturePoint('🧪 执行综合AVRCP功能测试'),
            _buildFeaturePoint('🎧 特别优化JBL Live Pro+ TWS'),
            _buildFeaturePoint('📊 提供详细的协议分析报告'),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard(BluetoothManager bluetoothManager) {
    bool isConnected = bluetoothManager.isConnected;
    Color statusColor = isConnected ? Colors.green : Colors.grey;

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
                  isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: statusColor,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '设备连接状态',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isConnected
                            ? '已连接: ${bluetoothManager.connectedDevice?.platformName ?? "未知设备"}'
                            : '未连接设备',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (isConnected) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✅ 设备已连接，可以开始AVRCP测试',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    if (bluetoothManager.avrcpSupported) ...[
                      SizedBox(height: 4),
                      Text(
                        '🎵 AVRCP协议: ${bluetoothManager.avrcpVersion}',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  '⚠️ 请先连接蓝牙音频设备以开始AVRCP验证',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(BuildContext context, BluetoothManager bluetoothManager) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '功能模块',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            // 设备连接和管理
            _buildNavigationButton(
              context,
              title: '设备连接和管理',
              subtitle: '扫描、连接蓝牙设备，查看电池状态',
              icon: Icons.bluetooth_searching,
              color: Colors.blue,
              onTap: () => Navigator.pushNamed(context, '/headphone'),
            ),

            SizedBox(height: 12),

            // AVRCP协议测试
            _buildNavigationButton(
              context,
              title: 'AVRCP协议测试',
              subtitle: '验证AVRCP功能，测试绝对音量控制',
              icon: Icons.science,
              color: Colors.green,
              enabled: bluetoothManager.isConnected,
              onTap: bluetoothManager.isConnected
                  ? () => Navigator.pushNamed(context, '/avrcp_test')
                  : null,
            ),

            if (!bluetoothManager.isConnected) ...[
              SizedBox(height: 8),
              Text(
                '* 需要先连接设备才能进行AVRCP测试',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAVRCPExplanationCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.purple, size: 24),
                SizedBox(width: 8),
                Text(
                  'AVRCP协议验证原理',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            Text(
              'AVRCP (Audio/Video Remote Control Profile) 是蓝牙音频设备的核心控制协议。本应用通过以下方式证明AVRCP正常工作：',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),

            _buildExplanationStep(
              '1. 协议检测',
              '扫描和识别设备支持的AVRCP服务和特征',
              Icons.search,
            ),
            _buildExplanationStep(
              '2. 版本确认',
              '读取和解析AVRCP协议版本号（1.3-1.6）',
              Icons.verified,
            ),
            _buildExplanationStep(
              '3. 功能验证',
              '通过绝对音量控制证明协议通信正常',
              Icons.volume_up,
            ),
            _buildExplanationStep(
              '4. 实时测试',
              '执行音量变化测试，验证设备响应',
              Icons.play_arrow,
            ),

            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Text(
                '💡 关键证明：如果您能通过应用程序控制耳机音量，就证明AVRCP协议正在工作！',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJBLSpecialCard() {
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
                  'JBL Live Pro+ TWS 专项支持',
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
                    '🎧 JBL Live Pro+ TWS 技术规格:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  SizedBox(height: 8),

                  Text('• AVRCP 1.5 协议支持', style: TextStyle(fontSize: 12)),
                  Text('• 绝对音量控制 (0-127范围)', style: TextStyle(fontSize: 12)),
                  Text('• 主动降噪控制集成', style: TextStyle(fontSize: 12)),
                  Text('• 自定义EQ设置支持', style: TextStyle(fontSize: 12)),
                  Text('• True Wireless 双耳独立连接', style: TextStyle(fontSize: 12)),

                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '✅ 本应用已针对JBL Live Pro+ TWS进行特别优化和测试',
                      style: TextStyle(
                        fontSize: 11,
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

  Widget _buildFeaturePoint(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildNavigationButton(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        bool enabled = true,
        VoidCallback? onTap,
      }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? color.withOpacity(0.3) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled ? color : Colors.grey.shade400,
              size: 32,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: enabled ? null : Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationStep(String title, String description, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.purple),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
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