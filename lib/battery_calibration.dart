import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BatteryCalibration {
  static const String _calibrationKey = 'battery_calibration_';

  // 获取设备的校准因子
  static Future<double> getCalibrationFactor(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_calibrationKey$deviceId') ?? 1.0;
  }

  // 保存设备的校准因子
  static Future<void> saveCalibrationFactor(String deviceId, double factor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_calibrationKey$deviceId', factor);
  }

  // 显示校准对话框
  static Future<void> showCalibrationDialog(
      BuildContext context,
      String deviceId,
      String deviceName,
      int currentDisplayed,
      Function(double) onCalibrationChanged,
      ) async {
    final TextEditingController actualController = TextEditingController();
    double currentFactor = await getCalibrationFactor(deviceId);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('电量校准'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('设备: $deviceName'),
                  SizedBox(height: 8),
                  Text('当前显示电量: $currentDisplayed%'),
                  SizedBox(height: 16),
                  TextField(
                    controller: actualController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '实际电量 (%)',
                      hintText: '请输入设备真实电量',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '当前校准因子: ${currentFactor.toStringAsFixed(3)}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '说明：输入设备的真实电量，系统将自动计算校准因子',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    // 重置校准
                    await saveCalibrationFactor(deviceId, 1.0);
                    onCalibrationChanged(1.0);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('校准已重置')),
                    );
                  },
                  child: Text('重置'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final actualText = actualController.text.trim();
                    if (actualText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('请输入实际电量')),
                      );
                      return;
                    }

                    final actualBattery = int.tryParse(actualText);
                    if (actualBattery == null || actualBattery < 0 || actualBattery > 100) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('请输入0-100之间的有效数值')),
                      );
                      return;
                    }

                    if (currentDisplayed == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('当前显示电量为0，无法校准')),
                      );
                      return;
                    }

                    // 计算校准因子
                    double newFactor = actualBattery / currentDisplayed;

                    // 限制校准因子的范围
                    newFactor = newFactor.clamp(0.5, 2.0);

                    await saveCalibrationFactor(deviceId, newFactor);
                    onCalibrationChanged(newFactor);

                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('校准完成！校准因子: ${newFactor.toStringAsFixed(3)}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: Text('保存校准'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}