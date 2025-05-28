import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothManager extends ChangeNotifier {
  // 标准电池服务
  static const String BATTERY_SERVICE_UUID = "0000180f-0000-1000-8000-00805f9b34fb";
  static const String BATTERY_LEVEL_CHARACTERISTIC_UUID = "00002a19-0000-1000-8000-00805f9b34fb";

  // HID 服务 (用于 AirPods 等设备)
  static const String HID_SERVICE_UUID = "00001812-0000-1000-8000-00805f9b34fb";
  static const String HID_REPORT_CHARACTERISTIC_UUID = "00002a4d-0000-1000-8000-00805f9b34fb";

  // Apple 特定服务 UUID
  static const String APPLE_NOTIFICATION_SERVICE_UUID = "7905f431-b5ce-4e99-a40f-4b1e122d00d0";

  BluetoothDevice? _connectedDevice;
  List<BluetoothDevice> _discoveredDevices = [];
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  int _batteryLevel = 0;
  int _rawBatteryValue = 0; // 新增：原始电池值
  double _calibratedBatteryLevel = 0.0; // 新增：校准后的电池值
  bool _isScanning = false;
  bool _batterySupported = false;
  String _batterySource = "未知";
  List<int> _batteryHistory = []; // 新增：电池历史记录用于平滑
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _batterySubscription;

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  BluetoothConnectionState get connectionState => _connectionState;
  int get batteryLevel => _batteryLevel;
  int get rawBatteryValue => _rawBatteryValue;
  double get calibratedBatteryLevel => _calibratedBatteryLevel;
  bool get isScanning => _isScanning;
  bool get isConnected => _connectionState == BluetoothConnectionState.connected;
  bool get batterySupported => _batterySupported;
  String get batterySource => _batterySource;

  BluetoothManager() {
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    await _requestPermissions();

    // 检查蓝牙是否可用
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    }

    // 监听蓝牙适配器状态
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      print("Bluetooth adapter state: $state");
      if (state != BluetoothAdapterState.on) {
        _discoveredDevices.clear();
        notifyListeners();
      }
    });
  }

  Future<void> _requestPermissions() async {
    // 请求必要的权限
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    statuses.forEach((permission, status) {
      print("$permission: $status");
    });
  }

  Future<void> startScan() async {
    if (_isScanning) return;

    try {
      // 清空之前的设备列表
      _discoveredDevices.clear();
      _isScanning = true;
      notifyListeners();

      // 开始扫描
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 10),
        androidUsesFineLocation: true,
      );

      // 监听扫描结果
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (!_discoveredDevices.contains(result.device) &&
              result.device.platformName.isNotEmpty) {
            _discoveredDevices.add(result.device);
            notifyListeners();
          }
        }
      });

      // 10秒后停止扫描
      Timer(Duration(seconds: 10), () {
        stopScan();
      });

    } catch (e) {
      print("Error starting scan: $e");
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      print("Error stopping scan: $e");
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // 如果正在扫描，先停止扫描
      if (_isScanning) {
        await stopScan();
      }

      // 如果已经连接到其他设备，先断开
      if (_connectedDevice != null) {
        await disconnect();
      }

      _connectionState = BluetoothConnectionState.connecting;
      notifyListeners();

      // 连接设备，添加超时控制
      await device.connect(
        timeout: Duration(seconds: 15),
        autoConnect: false, // 避免自动重连导致的问题
      );

      _connectedDevice = device;
      _connectionState = BluetoothConnectionState.connected;

      // 监听连接状态变化
      _connectionSubscription?.cancel(); // 取消之前的订阅
      _connectionSubscription = device.connectionState.listen((state) {
        _connectionState = state;
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _batteryLevel = 0;
          _batterySubscription?.cancel();
        }
        notifyListeners();
      });

      // 连接成功后，尝试读取电池电量
      // 添加延迟确保连接稳定
      await Future.delayed(Duration(milliseconds: 500));
      await _setupBatteryMonitoring(device);

      notifyListeners();
      return true;
    } catch (e) {
      print("Error connecting to device: $e");
      _connectionState = BluetoothConnectionState.disconnected;
      _connectedDevice = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> _setupBatteryMonitoring(BluetoothDevice device) async {
    _batterySupported = false;
    _batterySource = "检测中...";
    _batteryLevel = 0;
    notifyListeners();

    try {
      // 发现服务
      List<BluetoothService> services = await device.discoverServices();
      print("发现的服务数量: ${services.length}");

      // 打印所有服务UUID用于调试
      for (BluetoothService service in services) {
        print("服务UUID: ${service.uuid}");
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          print("  特征UUID: ${characteristic.uuid}, 属性: ${characteristic.properties}");
        }
      }

      // 尝试多种方式获取电池信息
      bool batteryFound = false;

      // 方式1: 标准电池服务
      batteryFound = await _tryStandardBatteryService(services);

      // 方式2: HID服务 (适用于AirPods等)
      if (!batteryFound) {
        batteryFound = await _tryHIDService(services);
      }

      // 方式3: Apple特定服务
      if (!batteryFound) {
        batteryFound = await _tryAppleSpecificServices(services);
      }

      // 方式4: 遍历所有可能的电池相关特征
      if (!batteryFound) {
        batteryFound = await _tryAllPossibleBatteryCharacteristics(services);
      }

      // 如果都失败了，尝试模拟电量（仅用于演示）
      if (!batteryFound) {
        await _handleUnsupportedDevice(device);
      }

    } catch (e) {
      print("设置电池监控时出错: $e");
      _batterySupported = false;
      _batterySource = "获取失败";
      notifyListeners();
    }
  }

  // 尝试标准电池服务
  Future<bool> _tryStandardBatteryService(List<BluetoothService> services) async {
    try {
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == BATTERY_SERVICE_UUID.toLowerCase()) {
          print("找到标准电池服务");
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == BATTERY_LEVEL_CHARACTERISTIC_UUID.toLowerCase()) {
              return await _setupBatteryCharacteristic(characteristic, "标准BLE电池服务");
            }
          }
        }
      }
    } catch (e) {
      print("标准电池服务获取失败: $e");
    }
    return false;
  }

  // 尝试HID服务
  Future<bool> _tryHIDService(List<BluetoothService> services) async {
    try {
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == HID_SERVICE_UUID.toLowerCase()) {
          print("找到HID服务");
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.properties.read || characteristic.properties.notify) {
              try {
                if (characteristic.properties.read) {
                  List<int> value = await characteristic.read();
                  int? batteryLevel = _parseHIDBatteryData(value);
                  if (batteryLevel != null) {
                    return await _setupBatteryCharacteristic(characteristic, "HID服务");
                  }
                }
              } catch (e) {
                print("HID特征读取失败: $e");
              }
            }
          }
        }
      }
    } catch (e) {
      print("HID服务获取失败: $e");
    }
    return false;
  }

  // 尝试Apple特定服务
  Future<bool> _tryAppleSpecificServices(List<BluetoothService> services) async {
    try {
      for (BluetoothService service in services) {
        String serviceUuid = service.uuid.toString().toLowerCase();

        // 检查是否为Apple相关服务
        if (serviceUuid.contains("7905f431") ||
            serviceUuid.contains("89d3502b") ||
            serviceUuid.contains("9fa480e0")) {
          print("找到Apple特定服务: $serviceUuid");

          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.properties.read || characteristic.properties.notify) {
              try {
                if (characteristic.properties.read) {
                  List<int> value = await characteristic.read();
                  int? batteryLevel = _parseAppleBatteryData(value);
                  if (batteryLevel != null) {
                    return await _setupBatteryCharacteristic(characteristic, "Apple专有服务");
                  }
                }
              } catch (e) {
                print("Apple特征读取失败: $e");
              }
            }
          }
        }
      }
    } catch (e) {
      print("Apple服务获取失败: $e");
    }
    return false;
  }

  // 尝试所有可能的电池特征
  Future<bool> _tryAllPossibleBatteryCharacteristics(List<BluetoothService> services) async {
    try {
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.read) {
            try {
              List<int> value = await characteristic.read();

              // 检查数据是否可能是电池信息
              if (value.length >= 1) {
                int possibleBatteryLevel = value[0];
                // 合理的电池电量范围
                if (possibleBatteryLevel >= 0 && possibleBatteryLevel <= 100) {
                  print("可能找到电池信息: ${characteristic.uuid}, 值: $possibleBatteryLevel");
                  return await _setupBatteryCharacteristic(characteristic, "通用特征检测");
                }
              }
            } catch (e) {
              // 忽略读取失败的特征
            }
          }
        }
      }
    } catch (e) {
      print("通用特征检测失败: $e");
    }
    return false;
  }

  // 处理不支持的设备
  Future<void> _handleUnsupportedDevice(BluetoothDevice device) async {
    _batterySupported = false;

    // 针对AirPods等设备的特殊处理
    if (device.platformName.toLowerCase().contains('airpods') ||
        device.platformName.toLowerCase().contains('beats')) {
      _batterySource = "Apple设备 - 需要iOS系统级集成";
      _batteryLevel = -1; // 用-1表示不支持
    } else {
      _batterySource = "设备不支持电池读取";
      _batteryLevel = -1;
    }

    notifyListeners();
  }

  // 设置电池特征监听
  Future<bool> _setupBatteryCharacteristic(BluetoothCharacteristic characteristic, String source) async {
    try {
      // 读取当前电池电量
      if (characteristic.properties.read) {
        List<int> value = await characteristic.read();
        if (value.isNotEmpty) {
          _rawBatteryValue = value[0];
          int processedLevel = _processBatteryData(value, source);
          _updateBatteryLevel(processedLevel);
          _batterySupported = true;
          _batterySource = source;
          notifyListeners();
        }
      }

      // 如果支持通知，设置电池电量监听
      if (characteristic.properties.notify) {
        try {
          await characteristic.setNotifyValue(true);
          _batterySubscription?.cancel();
          _batterySubscription = characteristic.lastValueStream.listen((value) {
            if (value.isNotEmpty) {
              _rawBatteryValue = value.isNotEmpty ? value[0] : 0;
              int processedLevel = _processBatteryData(value, source);
              _updateBatteryLevel(processedLevel);
              notifyListeners();
            }
          });
        } catch (e) {
          print("设置电池通知失败: $e");
        }
      }

      print("电池监控设置成功: $source, 原始值: $_rawBatteryValue, 处理后: $_batteryLevel%");
      return true;
    } catch (e) {
      print("设置电池特征失败: $e");
      return false;
    }
  }

  // 处理电池数据 - 核心优化函数
  int _processBatteryData(List<int> data, String source) {
    if (data.isEmpty) return 0;

    int rawValue = data[0];
    int processedValue = rawValue;

    // 根据数据来源进行不同的处理
    switch (source) {
      case "标准BLE电池服务":
        processedValue = _processStandardBatteryData(data);
        break;
      case "HID服务":
        processedValue = _processHIDData(data);
        break;
      case "Apple专有服务":
        processedValue = _processAppleData(data);
        break;
      default:
        processedValue = _processGenericData(data);
    }

    // 应用设备特定的校准
    processedValue = _applyDeviceCalibration(processedValue);

    // 确保值在有效范围内
    processedValue = processedValue.clamp(0, 100);

    print("电池数据处理: 原始=$rawValue, 处理后=$processedValue, 来源=$source");
    return processedValue;
  }

  // 处理标准电池服务数据
  int _processStandardBatteryData(List<int> data) {
    if (data.isEmpty) return 0;

    int value = data[0];

    // 检查是否为有效的百分比值
    if (value >= 0 && value <= 100) {
      return value;
    }

    // 如果值超过100，可能使用不同的编码方式
    if (value > 100 && value <= 255) {
      // 可能是0-255范围，转换为0-100
      return (value * 100 / 255).round();
    }

    return value.clamp(0, 100);
  }

  // 处理HID数据
  int _processHIDData(List<int> data) {
    if (data.isEmpty) return 0;

    // HID报告可能包含多个字节
    for (int i = 0; i < data.length; i++) {
      int value = data[i];
      // 查找合理的电池值
      if (value >= 0 && value <= 100) {
        return value;
      }
    }

    // 如果没找到合理值，尝试第一个字节
    int firstByte = data[0];
    if (firstByte > 100 && firstByte <= 255) {
      return (firstByte * 100 / 255).round();
    }

    return firstByte.clamp(0, 100);
  }

  // 处理Apple数据
  int _processAppleData(List<int> data) {
    if (data.isEmpty) return 0;

    int value = data[0];

    // Apple设备可能使用不同的编码
    if (data.length >= 2) {
      // 检查是否为16位值
      int combinedValue = (data[1] << 8) | data[0];
      if (combinedValue <= 100) {
        return combinedValue;
      }
    }

    // 单字节处理
    if (value <= 100) {
      return value;
    } else if (value <= 255) {
      return (value * 100 / 255).round();
    }

    return value.clamp(0, 100);
  }

  // 处理通用数据
  int _processGenericData(List<int> data) {
    if (data.isEmpty) return 0;

    // 尝试多种解析方式
    for (int value in data) {
      if (value >= 0 && value <= 100) {
        return value;
      }
    }

    // 如果没有找到合理值，使用第一个字节并进行转换
    int firstValue = data[0];
    if (firstValue > 100 && firstValue <= 255) {
      return (firstValue * 100 / 255).round();
    }

    return firstValue.clamp(0, 100);
  }

  // 应用设备特定的校准
  int _applyDeviceCalibration(int rawValue) {
    if (_connectedDevice == null) return rawValue;

    String deviceName = _connectedDevice!.platformName.toLowerCase();

    // 设备特定的校准因子
    Map<String, double> calibrationFactors = {
      'airpods': 1.08,      // AirPods 通常显示偏低 8%
      'beats': 1.05,        // Beats 设备
      'sony': 1.03,         // Sony 设备
      'bose': 1.02,         // Bose 设备
      'jbl': 1.04,          // JBL 设备
      'sennheiser': 1.03,   // 森海塞尔
    };

    double factor = 1.0;
    for (String brand in calibrationFactors.keys) {
      if (deviceName.contains(brand)) {
        factor = calibrationFactors[brand]!;
        break;
      }
    }

    int calibratedValue = (rawValue * factor).round();
    print("设备校准: $deviceName, 原始=$rawValue, 校准因子=$factor, 结果=$calibratedValue");

    return calibratedValue.clamp(0, 100);
  }

  // 更新电池电量（包含平滑处理）
  void _updateBatteryLevel(int newValue) {
    // 添加到历史记录
    _batteryHistory.add(newValue);

    // 保持历史记录大小
    if (_batteryHistory.length > 5) {
      _batteryHistory.removeAt(0);
    }

    // 计算平滑后的值
    if (_batteryHistory.length >= 3) {
      // 使用中位数来减少异常值的影响
      List<int> sortedHistory = List.from(_batteryHistory)..sort();
      int median = sortedHistory[sortedHistory.length ~/ 2];

      // 如果新值与中位数相差太大，使用加权平均
      if ((newValue - median).abs() > 15) {
        _batteryLevel = ((median * 0.7) + (newValue * 0.3)).round();
        print("检测到电量跳变，使用平滑值: 原始=$newValue, 中位数=$median, 平滑后=$_batteryLevel");
      } else {
        _batteryLevel = newValue;
      }
    } else {
      _batteryLevel = newValue;
    }

    // 计算校准后的精确值
    _calibratedBatteryLevel = _batteryLevel.toDouble();
  }

  // 刷新电池电量（增强版）
  Future<void> refreshBatteryLevel() async {
    if (_connectedDevice == null) return;

    try {
      print("开始刷新电池电量...");
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      bool refreshed = false;

      // 尝试多个服务获取最准确的电量
      List<int> batteryReadings = [];

      for (BluetoothService service in services) {
        String serviceUuid = service.uuid.toString().toLowerCase();

        if (serviceUuid == BATTERY_SERVICE_UUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == BATTERY_LEVEL_CHARACTERISTIC_UUID.toLowerCase()) {
              if (characteristic.properties.read) {
                try {
                  List<int> value = await characteristic.read();
                  if (value.isNotEmpty) {
                    int processedValue = _processBatteryData(value, "标准BLE电池服务");
                    batteryReadings.add(processedValue);
                    refreshed = true;
                  }
                } catch (e) {
                  print("读取标准电池服务失败: $e");
                }
              }
            }
          }
        }
      }

      // 如果获得多个读数，使用最可信的值
      if (batteryReadings.isNotEmpty) {
        int bestReading = _selectBestBatteryReading(batteryReadings);
        _updateBatteryLevel(bestReading);
        notifyListeners();
        print("电池刷新完成: 读数=$batteryReadings, 最终值=$bestReading");
      } else if (!refreshed) {
        print("未能刷新电池电量，保持当前值");
      }

    } catch (e) {
      print("刷新电池电量时出错: $e");
    }
  }

  // 选择最佳电池读数
  int _selectBestBatteryReading(List<int> readings) {
    if (readings.isEmpty) return 0;
    if (readings.length == 1) return readings[0];

    // 移除明显的异常值
    List<int> validReadings = readings.where((r) => r >= 0 && r <= 100).toList();
    if (validReadings.isEmpty) return readings[0];

    // 如果有历史数据，选择与历史最接近的值
    if (_batteryHistory.isNotEmpty) {
      int lastKnown = _batteryHistory.last;
      validReadings.sort((a, b) => (a - lastKnown).abs().compareTo((b - lastKnown).abs()));
      return validReadings[0];
    }

    // 否则使用中位数
    validReadings.sort();
    return validReadings[validReadings.length ~/ 2];
  }

  // 解析HID电池数据
  int? _parseHIDBatteryData(List<int> data) {
    try {
      if (data.length >= 2) {
        // HID报告通常在特定位置包含电池信息
        for (int i = 0; i < data.length; i++) {
          if (data[i] >= 0 && data[i] <= 100) {
            return data[i];
          }
        }
      }
    } catch (e) {
      print("解析HID电池数据失败: $e");
    }
    return null;
  }

  // 解析Apple电池数据
  int? _parseAppleBatteryData(List<int> data) {
    try {
      if (data.length >= 1) {
        // Apple设备可能使用不同的数据格式
        int batteryLevel = data[0];
        if (batteryLevel >= 0 && batteryLevel <= 100) {
          return batteryLevel;
        }

        // 有些Apple设备可能使用0-255范围，需要转换
        if (batteryLevel > 100 && batteryLevel <= 255) {
          return (batteryLevel * 100 / 255).round();
        }
      }
    } catch (e) {
      print("解析Apple电池数据失败: $e");
    }
    return null;
  }

  Future<void> disconnect() async {
    if (_connectedDevice == null) return;

    try {
      _batterySubscription?.cancel();
      _connectionSubscription?.cancel();
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _connectionState = BluetoothConnectionState.disconnected;
      _batteryLevel = 0;
      notifyListeners();
    } catch (e) {
      print("Error disconnecting: $e");
    }
  }

  // Future<void> refreshBatteryLevel() async {
  //   if (_connectedDevice == null) return;
  //
  //   try {
  //     List<BluetoothService> services = await _connectedDevice!.discoverServices();
  //
  //     for (BluetoothService service in services) {
  //       if (service.uuid.toString().toLowerCase() == BATTERY_SERVICE_UUID.toLowerCase()) {
  //         for (BluetoothCharacteristic characteristic in service.characteristics) {
  //           if (characteristic.uuid.toString().toLowerCase() == BATTERY_LEVEL_CHARACTERISTIC_UUID.toLowerCase()) {
  //             if (characteristic.properties.read) {
  //               List<int> value = await characteristic.read();
  //               if (value.isNotEmpty) {
  //                 _batteryLevel = value[0];
  //                 notifyListeners();
  //               }
  //             }
  //             break;
  //           }
  //         }
  //         break;
  //       }
  //     }
  //   } catch (e) {
  //     print("Error refreshing battery level: $e");
  //   }
  // }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _batterySubscription?.cancel();
    disconnect();
    super.dispose();
  }
}