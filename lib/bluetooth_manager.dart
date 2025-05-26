import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothManager extends ChangeNotifier {
  // 标准电池服务
  static const String BATTERY_SERVICE_UUID =
      "0000180f-0000-1000-8000-00805f9b34fb";
  static const String BATTERY_LEVEL_CHARACTERISTIC_UUID =
      "00002a19-0000-1000-8000-00805f9b34fb";

  // HID 服务 (用于 AirPods 等设备)
  static const String HID_SERVICE_UUID = "00001812-0000-1000-8000-00805f9b34fb";
  static const String HID_REPORT_CHARACTERISTIC_UUID =
      "00002a4d-0000-1000-8000-00805f9b34fb";

  // Apple 特定服务 UUID (一些 Apple 设备使用)
  static const String APPLE_NOTIFICATION_SERVICE_UUID =
      "7905f431-b5ce-4e99-a40f-4b1e122d00d0";

  BluetoothDevice? _connectedDevice;
  List<BluetoothDevice> _discoveredDevices = [];
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  int _batteryLevel = 0;
  bool _isScanning = false;
  bool _batterySupported = false; // 新增：标记设备是否支持电池读取
  String _batterySource = "未知"; // 新增：记录电池信息来源
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _batterySubscription;

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  BluetoothConnectionState get connectionState => _connectionState;
  int get batteryLevel => _batteryLevel;
  bool get isScanning => _isScanning;
  bool get isConnected =>
      _connectionState == BluetoothConnectionState.connected;
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
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          print(
              "  特征UUID: ${characteristic.uuid}, 属性: ${characteristic.properties}");
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
  Future<bool> _tryStandardBatteryService(
      List<BluetoothService> services) async {
    try {
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() ==
            BATTERY_SERVICE_UUID.toLowerCase()) {
          print("找到标准电池服务");
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() ==
                BATTERY_LEVEL_CHARACTERISTIC_UUID.toLowerCase()) {
              return await _setupBatteryCharacteristic(
                  characteristic, "标准BLE电池服务");
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
        if (service.uuid.toString().toLowerCase() ==
            HID_SERVICE_UUID.toLowerCase()) {
          print("找到HID服务");
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.properties.read ||
                characteristic.properties.notify) {
              try {
                if (characteristic.properties.read) {
                  List<int> value = await characteristic.read();
                  int? batteryLevel = _parseHIDBatteryData(value);
                  if (batteryLevel != null) {
                    return await _setupBatteryCharacteristic(
                        characteristic, "HID服务");
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
  Future<bool> _tryAppleSpecificServices(
      List<BluetoothService> services) async {
    try {
      for (BluetoothService service in services) {
        String serviceUuid = service.uuid.toString().toLowerCase();

        // 检查是否为Apple相关服务
        if (serviceUuid.contains("7905f431") ||
            serviceUuid.contains("89d3502b") ||
            serviceUuid.contains("9fa480e0")) {
          print("找到Apple特定服务: $serviceUuid");

          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.properties.read ||
                characteristic.properties.notify) {
              try {
                if (characteristic.properties.read) {
                  List<int> value = await characteristic.read();
                  int? batteryLevel = _parseAppleBatteryData(value);
                  if (batteryLevel != null) {
                    return await _setupBatteryCharacteristic(
                        characteristic, "Apple专有服务");
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
  Future<bool> _tryAllPossibleBatteryCharacteristics(
      List<BluetoothService> services) async {
    try {
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.properties.read) {
            try {
              List<int> value = await characteristic.read();

              // 检查数据是否可能是电池信息
              if (value.length >= 1) {
                int possibleBatteryLevel = value[0];
                // 合理的电池电量范围
                if (possibleBatteryLevel >= 0 && possibleBatteryLevel <= 100) {
                  print(
                      "可能找到电池信息: ${characteristic.uuid}, 值: $possibleBatteryLevel");
                  return await _setupBatteryCharacteristic(
                      characteristic, "通用特征检测");
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
  Future<bool> _setupBatteryCharacteristic(
      BluetoothCharacteristic characteristic, String source) async {
    try {
      // 读取当前电池电量
      if (characteristic.properties.read) {
        List<int> value = await characteristic.read();
        if (value.isNotEmpty) {
          _batteryLevel = value[0];
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
              _batteryLevel = value[0];
              notifyListeners();
            }
          });
        } catch (e) {
          print("设置电池通知失败: $e");
        }
      }

      print("电池监控设置成功: $source, 电量: $_batteryLevel%");
      return true;
    } catch (e) {
      print("设置电池特征失败: $e");
      return false;
    }
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

  Future<void> refreshBatteryLevel() async {
    if (_connectedDevice == null) return;

    try {
      List<BluetoothService> services =
          await _connectedDevice!.discoverServices();

      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() ==
            BATTERY_SERVICE_UUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() ==
                BATTERY_LEVEL_CHARACTERISTIC_UUID.toLowerCase()) {
              if (characteristic.properties.read) {
                List<int> value = await characteristic.read();
                if (value.isNotEmpty) {
                  _batteryLevel = value[0];
                  notifyListeners();
                }
              }
              break;
            }
          }
          break;
        }
      }
    } catch (e) {
      print("Error refreshing battery level: $e");
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _batterySubscription?.cancel();
    disconnect();
    super.dispose();
  }
}
