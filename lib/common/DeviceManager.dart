import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

class Device {
  final String ip;
  String name;
  bool isOnline;

  Device({required this.ip, required this.name, this.isOnline = true});
}

class DeviceManager extends ChangeNotifier {
  static final DeviceManager _instance = DeviceManager._internal();

  factory DeviceManager() => _instance;

  DeviceManager._internal();

  final Map<String, Device> _devices = {};
  final Map<String, DateTime> _deviceLastSeen = {};
  // ✅ 当前连接的 IP
  String _connectedIp = '';
  String get connectedIp => _connectedIp;
  /// 获取当前在线设备的列表（不可修改）
  UnmodifiableListView<Device> get devices =>
      UnmodifiableListView(_devices.values.where((d) => d.isOnline));

  Timer? _cleanupTimer;

  /// 添加或更新设备
  void addOrUpdateDevice(String ip, String? name) {
    final now = DateTime.now();
    _deviceLastSeen[ip] = now;

    if (_devices.containsKey(ip)) {
      final device = _devices[ip]!;
      device.name = name ?? device.name;
      device.isOnline = true;
    } else {
      _devices[ip] = Device(ip: ip, name: name ?? ip);
    }
    print(_devices);
    notifyListeners();
  }

  // /// 标记长时间未响应的设备为离线
  // void markOfflineDevices(Duration offlineDuration) {
  //   final now = DateTime.now();
  //   final offlineIps = <String>[];
  //
  //   for (var ip in _deviceLastSeen.keys) {
  //     if (now.difference(_deviceLastSeen[ip]!) > offlineDuration) {
  //       offlineIps.add(ip);
  //     }
  //   }
  //
  //   bool changed = false;
  //   for (var ip in offlineIps) {
  //     if (_devices[ip]?.isOnline == true) {
  //       _devices[ip]?.isOnline = false;
  //       changed = true;
  //     }
  //   }
  //   if (changed) notifyListeners();
  // }


  set connectedIp(String ip) {
    if (_connectedIp != ip) {
      _connectedIp = ip;
      notifyListeners(); // 连接变化也通知 UI 刷新
    }
  }

  /// 是否为当前连接的设备
  bool isConnected(String ip) => _connectedIp == ip;
  /// 删除设备
  void removeDevice(String ip) {
    _devices.remove(ip);
    _deviceLastSeen.remove(ip);
    notifyListeners();
  }

  /// 启动定时器，周期检查设备是否离线
  void startCleanupTimer() {
    // _cleanupTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
    //   markOfflineDevices(const Duration(seconds: 10));
    // });
  }

  /// 取消定时器，清理资源
  void disposeManager() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// 获取所有设备列表（包含离线）
  UnmodifiableListView<Device> get allDevices =>
      UnmodifiableListView(_devices.values);

  /// 手动获取设备列表（Map 转 List）
  List<Device> mapToList() {
    return _devices.entries.map((e) => e.value).toList();
  }
}
