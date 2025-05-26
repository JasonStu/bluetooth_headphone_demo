import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothManager extends ChangeNotifier {
  static const String BATTERY_SERVICE_UUID =
      "0000180f-0000-1000-8000-00805f9b34fb";
  static const String BATTERY_LEVEL_CHARACTERISTIC_UUID =
      "00002a19-0000-1000-8000-00805f9b34fb";

  BluetoothDevice? _connectedDevice;
  List<BluetoothDevice> _discoveredDevices = [];
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  int _batteryLevel = 0;
  bool _isScanning = false;
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

      // 连接设备
      await device.connect(timeout: Duration(seconds: 15));
      _connectedDevice = device;
      _connectionState = BluetoothConnectionState.connected;

      // 监听连接状态变化
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
    try {
      // 发现服务
      List<BluetoothService> services = await device.discoverServices();

      // 查找电池服务
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() ==
            BATTERY_SERVICE_UUID.toLowerCase()) {
          // 查找电池电量特征
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() ==
                BATTERY_LEVEL_CHARACTERISTIC_UUID.toLowerCase()) {
              // 读取当前电池电量
              if (characteristic.properties.read) {
                try {
                  List<int> value = await characteristic.read();
                  if (value.isNotEmpty) {
                    _batteryLevel = value[0];
                    notifyListeners();
                  }
                } catch (e) {
                  print("Error reading battery level: $e");
                }
              }

              // 如果支持通知，设置电池电量监听
              if (characteristic.properties.notify) {
                try {
                  await characteristic.setNotifyValue(true);
                  _batterySubscription =
                      characteristic.lastValueStream.listen((value) {
                    if (value.isNotEmpty) {
                      _batteryLevel = value[0];
                      notifyListeners();
                    }
                  });
                } catch (e) {
                  print("Error setting up battery notifications: $e");
                }
              }
              break;
            }
          }
          break;
        }
      }
    } catch (e) {
      print("Error setting up battery monitoring: $e");
    }
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
