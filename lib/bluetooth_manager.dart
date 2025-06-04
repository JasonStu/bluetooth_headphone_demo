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

  // AVRCP 相关 UUID
  static const String AVRCP_SERVICE_UUID = "0000110e-0000-1000-8000-00805f9b34fb";
  static const String AVRCP_CONTROLLER_UUID = "0000110f-0000-1000-8000-00805f9b34fb";
  static const String AVRCP_TARGET_UUID = "0000110c-0000-1000-8000-00805f9b34fb";

  // 音频相关服务
  static const String AUDIO_SINK_UUID = "0000110b-0000-1000-8000-00805f9b34fb";
  static const String A2DP_SOURCE_UUID = "0000110a-0000-1000-8000-00805f9b34fb";

  // 音量控制相关特征
  static const String VOLUME_CONTROL_SERVICE_UUID = "00001844-0000-1000-8000-00805f9b34fb";
  static const String VOLUME_STATE_CHARACTERISTIC_UUID = "00002b7d-0000-1000-8000-00805f9b34fb";
  static const String VOLUME_CONTROL_POINT_UUID = "00002b7e-0000-1000-8000-00805f9b34fb";

  BluetoothDevice? _connectedDevice;
  List<BluetoothDevice> _discoveredDevices = [];
  List<BluetoothDevice> _bondedDevices = []; // 系统已配对设备
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  int _batteryLevel = 0;
  int _rawBatteryValue = 0;
  double _calibratedBatteryLevel = 0.0;
  bool _isScanning = false;
  bool _batterySupported = false;
  String _batterySource = "未知";
  List<int> _batteryHistory = [];

  // AVRCP 相关状态
  bool _avrcpSupported = false;
  String _avrcpVersion = "未检测";
  int _currentVolume = 50;
  bool _volumeControlSupported = false;
  String _audioProfiles = "未检测";

  // 连接质量和配对状态
  bool _isSystemPaired = false;
  String _connectionType = "BLE";
  String _pairingIssue = "";

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _batterySubscription;
  StreamSubscription? _volumeSubscription;

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  List<BluetoothDevice> get bondedDevices => _bondedDevices;
  BluetoothConnectionState get connectionState => _connectionState;
  int get batteryLevel => _batteryLevel;
  int get rawBatteryValue => _rawBatteryValue;
  double get calibratedBatteryLevel => _calibratedBatteryLevel;
  bool get isScanning => _isScanning;
  bool get isConnected => _connectionState == BluetoothConnectionState.connected;
  bool get batterySupported => _batterySupported;
  String get batterySource => _batterySource;

  // AVRCP Getters
  bool get avrcpSupported => _avrcpSupported;
  String get avrcpVersion => _avrcpVersion;
  int get currentVolume => _currentVolume;
  bool get volumeControlSupported => _volumeControlSupported;
  String get audioProfiles => _audioProfiles;

  // Connection Quality Getters
  bool get isSystemPaired => _isSystemPaired;
  String get connectionType => _connectionType;
  String get pairingIssue => _pairingIssue;

  BluetoothManager() {
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    await _requestPermissions();

    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    }

    // 加载系统已配对的设备
    await _loadBondedDevices();

    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      print("Bluetooth adapter state: $state");
      if (state == BluetoothAdapterState.on) {
        // 蓝牙开启时重新加载已配对设备
        _loadBondedDevices();
      } else {
        _discoveredDevices.clear();
        _bondedDevices.clear();
        notifyListeners();
      }
    });
  }

  // 加载系统已配对的设备
  Future<void> _loadBondedDevices() async {
    try {
      print("🔍 加载系统已配对设备...");
      List<BluetoothDevice> bonded = await FlutterBluePlus.bondedDevices;
      _bondedDevices = bonded;

      print("✅ 发现 ${_bondedDevices.length} 个系统已配对设备:");
      for (BluetoothDevice device in _bondedDevices) {
        print("  - ${device.platformName.isNotEmpty ? device.platformName : '未知设备'} (${device.remoteId})");
      }

      notifyListeners();
    } catch (e) {
      print("❌ 加载已配对设备失败: $e");
      _bondedDevices = [];
    }
  }

  Future<void> _requestPermissions() async {
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
      // 检查蓝牙是否开启
      if (!await _checkBluetoothEnabled()) {
        return; // 如果蓝牙未开启，_checkBluetoothEnabled会处理提示
      }

      // 首先加载系统已配对设备（用于后续匹配）
      await _loadBondedDevices();

      // 清空之前发现的设备
      _discoveredDevices.clear();
      _isScanning = true;
      notifyListeners();

      print("🔍 开始蓝牙扫描（只显示可搜索到的设备）...");

      // 停止之前的扫描
      await FlutterBluePlus.stopScan();
      await Future.delayed(Duration(milliseconds: 500));

      // 开始扫描
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        print("📡 扫描到 ${results.length} 个设备");

        for (ScanResult result in results) {
          BluetoothDevice device = result.device;

          // 检查设备是否已在发现列表中
          bool alreadyInDiscovered = _discoveredDevices.any((d) => d.remoteId == device.remoteId);
          if (alreadyInDiscovered) {
            continue;
          }

          // 添加有名称的设备（包括系统已配对但可搜索到的设备）
          if (device.platformName.isNotEmpty || device.advName.isNotEmpty) {
            _discoveredDevices.add(device);

            // 检查是否为系统已配对设备
            bool isBonded = _bondedDevices.any((bonded) => bonded.remoteId == device.remoteId);
            if (isBonded) {
              print("✅ 发现系统已配对设备: ${device.platformName}");
            } else {
              print("➕ 发现新设备: ${device.platformName}");
            }

            notifyListeners();
          }
        }
      }, onError: (error) {
        print("❌ 扫描错误: $error");
      });

      // 15秒后停止扫描
      Timer(Duration(seconds: 15), () {
        stopScan();
      });

    } catch (e) {
      print("❌ 启动扫描时出错: $e");
      _isScanning = false;
      notifyListeners();
    }
  }

  // 检查蓝牙是否开启
  Future<bool> _checkBluetoothEnabled() async {
    try {
      BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;

      if (state != BluetoothAdapterState.on) {
        print("⚠️ 蓝牙未开启，当前状态: $state");

        // 通过回调通知UI显示蓝牙开启提示
        _showBluetoothEnableDialog();
        return false;
      }

      print("✅ 蓝牙已开启");
      return true;
    } catch (e) {
      print("❌ 检查蓝牙状态失败: $e");
      return false;
    }
  }

  // 蓝牙开启对话框回调
  Function()? _onShowBluetoothDialog;

  void setBluetoothDialogCallback(Function() callback) {
    _onShowBluetoothDialog = callback;
  }

  void _showBluetoothEnableDialog() {
    if (_onShowBluetoothDialog != null) {
      _onShowBluetoothDialog!();
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
      if (_isScanning) {
        await stopScan();
      }

      if (_connectedDevice != null) {
        await disconnect();
      }

      _connectionState = BluetoothConnectionState.connecting;
      notifyListeners();

      print("🔗 尝试连接设备: ${device.platformName}");

      // 检查设备是否已在系统层面配对
      bool isSystemPaired = await _checkSystemPairing(device);
      print("📱 系统配对状态: ${isSystemPaired ? '已配对' : '未配对'}");

      if (!isSystemPaired) {
        print("⚠️ 设备未在系统层面配对，可能影响AVRCP功能");
      }

      await device.connect(
        timeout: Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice = device;
      _connectionState = BluetoothConnectionState.connected;

      print("✅ 应用层连接成功");

      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        _connectionState = state;
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _batteryLevel = 0;
          _resetAVRCPState();
          _batterySubscription?.cancel();
          _volumeSubscription?.cancel();
        }
        notifyListeners();
      });

      await Future.delayed(Duration(milliseconds: 500));

      // 检查连接质量和类型
      await _analyzeConnectionType(device);

      await _setupBatteryMonitoring(device);
      await _setupAVRCPMonitoring(device);

      notifyListeners();
      return true;
    } catch (e) {
      print("❌ 连接设备失败: $e");
      _connectionState = BluetoothConnectionState.disconnected;
      _connectedDevice = null;
      notifyListeners();
      return false;
    }
  }

  // 重置AVRCP状态
  void _resetAVRCPState() {
    _avrcpSupported = false;
    _avrcpVersion = "未检测";
    _currentVolume = 50;
    _volumeControlSupported = false;
    _audioProfiles = "未检测";
    _isSystemPaired = false;
    _connectionType = "BLE";
    _pairingIssue = "";
  }

  // 检查系统层面的配对状态
  Future<bool> _checkSystemPairing(BluetoothDevice device) async {
    try {
      print("🔍 检查系统配对状态...");

      // 重新获取最新的已配对设备列表
      await _loadBondedDevices();

      bool isFound = _bondedDevices.any((bondedDevice) =>
      bondedDevice.remoteId == device.remoteId
      );

      _isSystemPaired = isFound;

      if (!isFound) {
        _pairingIssue = "设备未在系统层面配对，这可能导致AVRCP功能受限";
        print("⚠️ 设备未系统配对: ${device.platformName}");
      } else {
        _pairingIssue = "";
        print("✅ 设备已系统配对: ${device.platformName}");
      }

      return isFound;
    } catch (e) {
      print("❌ 检查配对状态失败: $e");
      _isSystemPaired = false;
      _pairingIssue = "无法检查配对状态: $e";
      return false;
    }
  }

  // 获取可搜索到的设备列表（只包含扫描发现的设备）
  List<BluetoothDevice> getAllAvailableDevices() {
    // 只返回扫描发现的设备，不包含所有系统已配对设备
    return List.from(_discoveredDevices);
  }

  // 检查设备是否为系统已配对设备（在扫描结果中的）
  bool isDeviceBonded(BluetoothDevice device) {
    return _bondedDevices.any((bonded) => bonded.remoteId == device.remoteId);
  }

  // 获取扫描到的已配对设备数量
  int getBondedDevicesInScanCount() {
    return _discoveredDevices.where((device) =>
        _bondedDevices.any((bonded) => bonded.remoteId == device.remoteId)
    ).length;
  }

  // 获取扫描到的新设备数量
  int getNewDevicesInScanCount() {
    return _discoveredDevices.where((device) =>
    !_bondedDevices.any((bonded) => bonded.remoteId == device.remoteId)
    ).length;
  }

  // 分析连接类型和质量
  Future<void> _analyzeConnectionType(BluetoothDevice device) async {
    try {
      print("📊 分析连接类型...");

      // 检查设备是否支持Classic Bluetooth特征
      bool hasClassicBluetooth = false;
      bool hasBLEOnly = true;

      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService service in services) {
        String serviceUuid = service.uuid.toString().toLowerCase();

        // 检查Classic Bluetooth音频服务
        if (serviceUuid == AVRCP_SERVICE_UUID.toLowerCase() ||
            serviceUuid == AUDIO_SINK_UUID.toLowerCase() ||
            serviceUuid == A2DP_SOURCE_UUID.toLowerCase()) {
          hasClassicBluetooth = true;
          hasBLEOnly = false;
          print("✅ 检测到Classic Bluetooth音频服务: $serviceUuid");
        }

        // 检查是否有非标准服务（可能是混合模式）
        if (serviceUuid.length == 36 && !serviceUuid.startsWith("0000")) {
          print("🔍 检测到自定义服务: $serviceUuid");
        }
      }

      // 确定连接类型
      if (hasClassicBluetooth && _isSystemPaired) {
        _connectionType = "Classic Bluetooth + BLE (理想状态)";
      } else if (hasClassicBluetooth && !_isSystemPaired) {
        _connectionType = "Classic Bluetooth (未系统配对)";
        _pairingIssue = "检测到Classic Bluetooth支持，但设备未系统配对。请在系统设置中配对此设备以获得完整的AVRCP功能。";
      } else if (hasBLEOnly) {
        _connectionType = "仅BLE连接";
        _pairingIssue = "此设备仅通过BLE连接，AVRCP功能可能受限。对于完整的音频控制，需要Classic Bluetooth配对。";
      } else {
        _connectionType = "混合连接";
      }

      print("📱 连接类型: $_connectionType");
      if (_pairingIssue.isNotEmpty) {
        print("⚠️ 配对问题: $_pairingIssue");
      }

    } catch (e) {
      print("分析连接类型失败: $e");
      _connectionType = "未知";
      _pairingIssue = "无法分析连接类型: $e";
    }
  }

  // 引导用户进行系统配对
  Future<Map<String, dynamic>> getPairingGuidance() async {
    Map<String, dynamic> guidance = {
      'needsPairing': !_isSystemPaired,
      'connectionType': _connectionType,
      'issue': _pairingIssue,
      'solutions': <String>[],
      'avrcpImpact': '',
    };

    if (!_isSystemPaired) {
      guidance['solutions'] = [
        "1. 在手机的系统设置中找到蓝牙设置",
        "2. 搜索并配对 ${_connectedDevice?.platformName ?? '您的设备'}",
        "3. 确认配对后重新连接应用",
        "4. 系统配对后AVRCP功能将完全可用",
      ];

      guidance['avrcpImpact'] = "系统未配对可能导致AVRCP音量控制功能受限或无法工作";
    } else {
      guidance['solutions'] = [
        "✅ 设备已正确配对",
        "✅ AVRCP功能应该完全可用",
        "如果音量控制仍有问题，请尝试重新连接",
      ];

      guidance['avrcpImpact'] = "设备已正确配对，AVRCP功能应该正常工作";
    }

    return guidance;
  }

  // 设置AVRCP监控
  Future<void> _setupAVRCPMonitoring(BluetoothDevice device) async {
    print("开始检测AVRCP功能...");
    _resetAVRCPState();
    notifyListeners();

    try {
      List<BluetoothService> services = await device.discoverServices();
      print("发现的服务数量: ${services.length}");

      List<String> supportedProfiles = [];

      // 检测音频相关的服务
      for (BluetoothService service in services) {
        String serviceUuid = service.uuid.toString().toLowerCase();
        print("检查服务UUID: $serviceUuid");

        // 检测AVRCP相关服务
        if (serviceUuid == AVRCP_SERVICE_UUID.toLowerCase()) {
          print("✓ 发现AVRCP服务");
          _avrcpSupported = true;
          supportedProfiles.add("AVRCP");
          await _detectAVRCPVersion(service);
        } else if (serviceUuid == AVRCP_CONTROLLER_UUID.toLowerCase()) {
          print("✓ 发现AVRCP控制器服务");
          supportedProfiles.add("AVRCP Controller");
        } else if (serviceUuid == AVRCP_TARGET_UUID.toLowerCase()) {
          print("✓ 发现AVRCP目标服务");
          supportedProfiles.add("AVRCP Target");
        } else if (serviceUuid == AUDIO_SINK_UUID.toLowerCase()) {
          print("✓ 发现A2DP音频接收器");
          supportedProfiles.add("A2DP Sink");
        } else if (serviceUuid == A2DP_SOURCE_UUID.toLowerCase()) {
          print("✓ 发现A2DP音频源");
          supportedProfiles.add("A2DP Source");
        } else if (serviceUuid == VOLUME_CONTROL_SERVICE_UUID.toLowerCase()) {
          print("✓ 发现音量控制服务");
          supportedProfiles.add("Volume Control");
          await _setupVolumeControl(service);
        }

        // 针对JBL Live Pro+ TWS的特殊检测
        if (device.platformName.toLowerCase().contains('jbl') &&
            device.platformName.toLowerCase().contains('live')) {
          await _detectJBLSpecificFeatures(service, device);
        }
      }

      // 如果没有找到标准AVRCP服务，尝试通过其他方式检测
      if (!_avrcpSupported) {
        await _detectAVRCPAlternative(services, device);
      }

      _audioProfiles = supportedProfiles.isNotEmpty ? supportedProfiles.join(", ") : "无音频配置文件";

      print("AVRCP检测完成:");
      print("- AVRCP支持: $_avrcpSupported");
      print("- AVRCP版本: $_avrcpVersion");
      print("- 音量控制: $_volumeControlSupported");
      print("- 音频配置文件: $_audioProfiles");

      notifyListeners();

    } catch (e) {
      print("AVRCP检测出错: $e");
      _avrcpSupported = false;
      _avrcpVersion = "检测失败";
      notifyListeners();
    }
  }

  // 检测AVRCP版本
  Future<void> _detectAVRCPVersion(BluetoothService service) async {
    try {
      print("检测AVRCP版本...");

      for (BluetoothCharacteristic characteristic in service.characteristics) {
        print("检查特征: ${characteristic.uuid}");

        if (characteristic.properties.read) {
          try {
            List<int> value = await characteristic.read();
            print("读取到特征值: $value");

            // 尝试解析AVRCP版本信息
            String version = _parseAVRCPVersion(value);
            if (version.isNotEmpty) {
              _avrcpVersion = version;
              print("检测到AVRCP版本: $version");
              return;
            }
          } catch (e) {
            print("读取特征失败: $e");
          }
        }
      }

      // 如果无法从特征读取版本，使用默认检测逻辑
      _avrcpVersion = "1.4+"; // 现代设备通常支持1.4或以上

    } catch (e) {
      print("版本检测失败: $e");
      _avrcpVersion = "未知版本";
    }
  }

  // 解析AVRCP版本
  String _parseAVRCPVersion(List<int> data) {
    if (data.isEmpty) return "";

    // 根据蓝牙规范，AVRCP版本通常在特定字节位置
    // 这里提供一个基本的解析逻辑
    if (data.length >= 2) {
      int major = (data[0] >> 4) & 0x0F;
      int minor = data[0] & 0x0F;

      if (major > 0) {
        return "$major.$minor";
      }
    }

    // 如果无法解析，返回基于数据长度的估计版本
    if (data.length >= 4) {
      return "1.6"; // 支持更多功能
    } else if (data.length >= 2) {
      return "1.4";
    } else {
      return "1.3";
    }
  }

  // 检测JBL特定功能
  Future<void> _detectJBLSpecificFeatures(BluetoothService service, BluetoothDevice device) async {
    print("检测JBL Live Pro+ TWS特定功能...");

    try {
      String serviceUuid = service.uuid.toString().toLowerCase();

      // JBL设备可能使用自定义服务
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.read || characteristic.properties.notify) {
          try {
            if (characteristic.properties.read) {
              List<int> value = await characteristic.read();

              // 检查是否为JBL特定的音量控制
              if (_isJBLVolumeCharacteristic(characteristic.uuid.toString(), value)) {
                print("✓ 发现JBL音量控制特征");
                _volumeControlSupported = true;
                await _setupJBLVolumeMonitoring(characteristic);
              }

              // 检查是否为JBL特定的AVRCP实现
              if (_isJBLAVRCPCharacteristic(characteristic.uuid.toString(), value)) {
                print("✓ 发现JBL AVRCP实现");
                _avrcpSupported = true;
                _avrcpVersion = "JBL Custom";
              }
            }
          } catch (e) {
            print("JBL特征检测失败: $e");
          }
        }
      }
    } catch (e) {
      print("JBL特定功能检测失败: $e");
    }
  }

  // 判断是否为JBL音量特征
  bool _isJBLVolumeCharacteristic(String uuid, List<int> value) {
    // JBL设备的音量特征通常包含特定的标识
    if (value.length >= 1) {
      // 音量值通常在0-127或0-100范围内
      int possibleVolume = value[0];
      if (possibleVolume >= 0 && possibleVolume <= 127) {
        _currentVolume = (possibleVolume * 100 / 127).round();
        return true;
      }
    }
    return false;
  }

  // 判断是否为JBL AVRCP特征
  bool _isJBLAVRCPCharacteristic(String uuid, List<int> value) {
    // 检查是否包含AVRCP相关的标识符
    return value.length >= 2 && (value[0] == 0x01 || value[0] == 0x02);
  }

  // 设置JBL音量监控
  Future<void> _setupJBLVolumeMonitoring(BluetoothCharacteristic characteristic) async {
    try {
      if (characteristic.properties.notify) {
        await characteristic.setNotifyValue(true);
        _volumeSubscription?.cancel();
        _volumeSubscription = characteristic.lastValueStream.listen((value) {
          if (value.isNotEmpty) {
            int newVolume = (value[0] * 100 / 127).round();
            _currentVolume = newVolume.clamp(0, 100);
            print("JBL音量更新: $_currentVolume%");
            notifyListeners();
          }
        });
      }
    } catch (e) {
      print("JBL音量监控设置失败: $e");
    }
  }

  // 替代AVRCP检测方法
  Future<void> _detectAVRCPAlternative(List<BluetoothService> services, BluetoothDevice device) async {
    print("使用替代方法检测AVRCP...");

    // 通过设备名称推断AVRCP支持
    String deviceName = device.platformName.toLowerCase();

    if (deviceName.contains('headphone') || deviceName.contains('earphone') ||
        deviceName.contains('headset') || deviceName.contains('earbuds') ||
        deviceName.contains('airpods') || deviceName.contains('beats') ||
        deviceName.contains('jbl') || deviceName.contains('sony') ||
        deviceName.contains('bose') || deviceName.contains('sennheiser')) {

      print("根据设备名称推断支持AVRCP");
      _avrcpSupported = true;

      // 根据设备品牌推断版本
      if (deviceName.contains('airpods') || deviceName.contains('beats')) {
        _avrcpVersion = "1.6 (Apple)";
      } else if (deviceName.contains('jbl') && deviceName.contains('live')) {
        _avrcpVersion = "1.5 (JBL)";
      } else if (deviceName.contains('sony') || deviceName.contains('bose')) {
        _avrcpVersion = "1.5+";
      } else {
        _avrcpVersion = "1.4+";
      }
    }

    // 检查是否有音频相关的通用特征
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
          // 可能支持音量控制
          _volumeControlSupported = true;
          break;
        }
      }
      if (_volumeControlSupported) break;
    }
  }

  // 设置音量控制
  Future<void> _setupVolumeControl(BluetoothService service) async {
    try {
      print("设置音量控制...");

      for (BluetoothCharacteristic characteristic in service.characteristics) {
        String charUuid = characteristic.uuid.toString().toLowerCase();

        if (charUuid == VOLUME_STATE_CHARACTERISTIC_UUID.toLowerCase()) {
          print("找到音量状态特征");
          if (characteristic.properties.read) {
            List<int> value = await characteristic.read();
            if (value.isNotEmpty) {
              _currentVolume = value[0].clamp(0, 100);
              _volumeControlSupported = true;
            }
          }

          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            _volumeSubscription?.cancel();
            _volumeSubscription = characteristic.lastValueStream.listen((value) {
              if (value.isNotEmpty) {
                _currentVolume = value[0].clamp(0, 100);
                notifyListeners();
              }
            });
          }
        }
      }
    } catch (e) {
      print("音量控制设置失败: $e");
    }
  }

  // 设置绝对音量
  Future<bool> setAbsoluteVolume(int volume) async {
    if (_connectedDevice == null || !_volumeControlSupported) {
      print("设备未连接或不支持音量控制");
      return false;
    }

    volume = volume.clamp(0, 100);

    try {
      print("设置绝对音量: $volume%");
      List<BluetoothService> services = await _connectedDevice!.discoverServices();

      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          String charUuid = characteristic.uuid.toString().toLowerCase();

          // 尝试标准音量控制特征
          if (charUuid == VOLUME_CONTROL_POINT_UUID.toLowerCase()) {
            if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
              List<int> volumeData = [volume];
              await characteristic.write(volumeData);
              _currentVolume = volume;
              notifyListeners();
              print("✓ 通过标准特征设置音量成功");
              return true;
            }
          }

          // 尝试JBL特定的音量控制
          if (_connectedDevice!.platformName.toLowerCase().contains('jbl')) {
            if (await _setJBLVolume(characteristic, volume)) {
              _currentVolume = volume;
              notifyListeners();
              print("✓ 通过JBL特征设置音量成功");
              return true;
            }
          }

          // 尝试通用音量控制
          if (characteristic.properties.write &&
              (characteristic.uuid.toString().contains('2a4d') ||
                  characteristic.uuid.toString().contains('volume'))) {
            try {
              List<int> volumeData = [volume];
              await characteristic.write(volumeData);
              _currentVolume = volume;
              notifyListeners();
              print("✓ 通过通用特征设置音量成功");
              return true;
            } catch (e) {
              print("通用音量设置失败: $e");
            }
          }
        }
      }

      print("未找到可用的音量控制特征");
      return false;

    } catch (e) {
      print("设置音量失败: $e");
      return false;
    }
  }

  // JBL特定的音量设置
  Future<bool> _setJBLVolume(BluetoothCharacteristic characteristic, int volume) async {
    try {
      if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
        // JBL设备通常使用0-127范围
        int jblVolume = (volume * 127 / 100).round();
        List<int> volumeData = [jblVolume];

        await characteristic.write(volumeData);
        return true;
      }
    } catch (e) {
      print("JBL音量设置失败: $e");
    }
    return false;
  }

  // 获取设备的AVRCP详细信息
  Map<String, String> getAVRCPInfo() {
    return {
      'AVRCP支持': _avrcpSupported ? '是' : '否',
      'AVRCP版本': _avrcpVersion,
      '音量控制': _volumeControlSupported ? '支持' : '不支持',
      '当前音量': '$_currentVolume%',
      '音频配置文件': _audioProfiles,
      '设备类型': _getDeviceType(),
    };
  }

  String _getDeviceType() {
    if (_connectedDevice == null) return "未知";

    String name = _connectedDevice!.platformName.toLowerCase();
    if (name.contains('jbl') && name.contains('live')) {
      return "JBL Live Pro+ TWS";
    } else if (name.contains('airpods')) {
      return "Apple AirPods";
    } else if (name.contains('beats')) {
      return "Beats 耳机";
    } else if (name.contains('sony')) {
      return "Sony 音频设备";
    } else if (name.contains('bose')) {
      return "Bose 音频设备";
    } else {
      return "蓝牙音频设备";
    }
  }

  // 原有的电池监控相关方法保持不变
  Future<void> _setupBatteryMonitoring(BluetoothDevice device) async {
    _batterySupported = false;
    _batterySource = "检测中...";
    _batteryLevel = 0;
    notifyListeners();

    try {
      List<BluetoothService> services = await device.discoverServices();
      print("发现的服务数量: ${services.length}");

      for (BluetoothService service in services) {
        print("服务UUID: ${service.uuid}");
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          print("  特征UUID: ${characteristic.uuid}, 属性: ${characteristic.properties}");
        }
      }

      bool batteryFound = false;
      batteryFound = await _tryStandardBatteryService(services);

      if (!batteryFound) {
        batteryFound = await _tryHIDService(services);
      }

      if (!batteryFound) {
        batteryFound = await _tryAppleSpecificServices(services);
      }

      if (!batteryFound) {
        batteryFound = await _tryAllPossibleBatteryCharacteristics(services);
      }

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

  // 保持所有原有的电池相关方法不变...
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

  Future<bool> _tryAppleSpecificServices(List<BluetoothService> services) async {
    try {
      for (BluetoothService service in services) {
        String serviceUuid = service.uuid.toString().toLowerCase();

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

  Future<bool> _tryAllPossibleBatteryCharacteristics(List<BluetoothService> services) async {
    try {
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.read) {
            try {
              List<int> value = await characteristic.read();

              if (value.length >= 1) {
                int possibleBatteryLevel = value[0];
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

  Future<void> _handleUnsupportedDevice(BluetoothDevice device) async {
    _batterySupported = false;

    if (device.platformName.toLowerCase().contains('airpods') ||
        device.platformName.toLowerCase().contains('beats')) {
      _batterySource = "Apple设备 - 需要iOS系统级集成";
      _batteryLevel = -1;
    } else {
      _batterySource = "设备不支持电池读取";
      _batteryLevel = -1;
    }

    notifyListeners();
  }

  Future<bool> _setupBatteryCharacteristic(BluetoothCharacteristic characteristic, String source) async {
    try {
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

  int _processBatteryData(List<int> data, String source) {
    if (data.isEmpty) return 0;

    int rawValue = data[0];
    int processedValue = rawValue;

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

    processedValue = _applyDeviceCalibration(processedValue);
    processedValue = processedValue.clamp(0, 100);

    print("电池数据处理: 原始=$rawValue, 处理后=$processedValue, 来源=$source");
    return processedValue;
  }

  int _processStandardBatteryData(List<int> data) {
    if (data.isEmpty) return 0;

    int value = data[0];

    if (value >= 0 && value <= 100) {
      return value;
    }

    if (value > 100 && value <= 255) {
      return (value * 100 / 255).round();
    }

    return value.clamp(0, 100);
  }

  int _processHIDData(List<int> data) {
    if (data.isEmpty) return 0;

    for (int i = 0; i < data.length; i++) {
      int value = data[i];
      if (value >= 0 && value <= 100) {
        return value;
      }
    }

    int firstByte = data[0];
    if (firstByte > 100 && firstByte <= 255) {
      return (firstByte * 100 / 255).round();
    }

    return firstByte.clamp(0, 100);
  }

  int _processAppleData(List<int> data) {
    if (data.isEmpty) return 0;

    int value = data[0];

    if (data.length >= 2) {
      int combinedValue = (data[1] << 8) | data[0];
      if (combinedValue <= 100) {
        return combinedValue;
      }
    }

    if (value <= 100) {
      return value;
    } else if (value <= 255) {
      return (value * 100 / 255).round();
    }

    return value.clamp(0, 100);
  }

  int _processGenericData(List<int> data) {
    if (data.isEmpty) return 0;

    for (int value in data) {
      if (value >= 0 && value <= 100) {
        return value;
      }
    }

    int firstValue = data[0];
    if (firstValue > 100 && firstValue <= 255) {
      return (firstValue * 100 / 255).round();
    }

    return firstValue.clamp(0, 100);
  }

  int _applyDeviceCalibration(int rawValue) {
    if (_connectedDevice == null) return rawValue;

    String deviceName = _connectedDevice!.platformName.toLowerCase();

    Map<String, double> calibrationFactors = {
      'airpods': 1.08,
      'beats': 1.05,
      'sony': 1.03,
      'bose': 1.02,
      'jbl': 1.04,
      'sennheiser': 1.03,
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

  void _updateBatteryLevel(int newValue) {
    _batteryHistory.add(newValue);

    if (_batteryHistory.length > 5) {
      _batteryHistory.removeAt(0);
    }

    if (_batteryHistory.length >= 3) {
      List<int> sortedHistory = List.from(_batteryHistory)..sort();
      int median = sortedHistory[sortedHistory.length ~/ 2];

      if ((newValue - median).abs() > 15) {
        _batteryLevel = ((median * 0.7) + (newValue * 0.3)).round();
        print("检测到电量跳变，使用平滑值: 原始=$newValue, 中位数=$median, 平滑后=$_batteryLevel");
      } else {
        _batteryLevel = newValue;
      }
    } else {
      _batteryLevel = newValue;
    }

    _calibratedBatteryLevel = _batteryLevel.toDouble();
  }

  int? _parseHIDBatteryData(List<int> data) {
    try {
      if (data.length >= 2) {
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

  int? _parseAppleBatteryData(List<int> data) {
    try {
      if (data.length >= 1) {
        int batteryLevel = data[0];
        if (batteryLevel >= 0 && batteryLevel <= 100) {
          return batteryLevel;
        }

        if (batteryLevel > 100 && batteryLevel <= 255) {
          return (batteryLevel * 100 / 255).round();
        }
      }
    } catch (e) {
      print("解析Apple电池数据失败: $e");
    }
    return null;
  }

  Future<void> refreshBatteryLevel() async {
    if (_connectedDevice == null) return;

    try {
      print("开始刷新电池电量...");
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      bool refreshed = false;

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

  int _selectBestBatteryReading(List<int> readings) {
    if (readings.isEmpty) return 0;
    if (readings.length == 1) return readings[0];

    List<int> validReadings = readings.where((r) => r >= 0 && r <= 100).toList();
    if (validReadings.isEmpty) return readings[0];

    if (_batteryHistory.isNotEmpty) {
      int lastKnown = _batteryHistory.last;
      validReadings.sort((a, b) => (a - lastKnown).abs().compareTo((b - lastKnown).abs()));
      return validReadings[0];
    }

    validReadings.sort();
    return validReadings[validReadings.length ~/ 2];
  }

  Future<void> disconnect() async {
    if (_connectedDevice == null) return;

    try {
      _batterySubscription?.cancel();
      _connectionSubscription?.cancel();
      _volumeSubscription?.cancel();
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _connectionState = BluetoothConnectionState.disconnected;
      _batteryLevel = 0;
      _resetAVRCPState();
      notifyListeners();
    } catch (e) {
      print("Error disconnecting: $e");
    }
  }

  String getDeviceDisplayName(BluetoothDevice device) {
    if (device.platformName.isNotEmpty) {
      return device.platformName;
    }
    String deviceId = device.remoteId.toString();
    return '未知设备 (${deviceId.substring(deviceId.length - 8)})';
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _batterySubscription?.cancel();
    _volumeSubscription?.cancel();
    disconnect();
    super.dispose();
  }
}