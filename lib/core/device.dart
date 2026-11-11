import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'storage.dart';

/// What the server needs to know about this phone (sent at login).
class DeviceSnapshot {
  DeviceSnapshot({required this.uid, required this.platform, required this.model, required this.manufacturer, required this.osVersion, required this.appVersion});

  final String uid;
  final String platform; // ANDROID | IOS
  final String model;
  final String manufacturer;
  final String osVersion;
  final String appVersion;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'platform': platform,
        'model': model,
        'manufacturer': manufacturer,
        'os_version': osVersion,
        'app_version': appVersion,
      };

  static DeviceSnapshot? _cached;

  static Future<DeviceSnapshot> read() async {
    if (_cached != null) return _cached!;
    final uid = await TokenStore.deviceUid();
    final pkg = await PackageInfo.fromPlatform();
    final info = DeviceInfoPlugin();
    String model = 'Unknown', maker = '', os = '', platform = 'ANDROID';
    try {
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        model = a.model;
        maker = a.manufacturer;
        os = 'Android ${a.version.release}';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        platform = 'IOS';
        model = i.modelName.isNotEmpty ? i.modelName : i.utsname.machine;
        maker = 'Apple';
        os = 'iOS ${i.systemVersion}';
      }
    } catch (_) {
      // device details are nice to have, never block login on them
    }
    _cached = DeviceSnapshot(
      uid: uid,
      platform: platform,
      model: _cut(model, 100),
      manufacturer: _cut(maker, 60),
      osVersion: _cut(os, 30),
      appVersion: _cut(pkg.version, 20),
    );
    return _cached!;
  }

  static String _cut(String s, int n) => s.length > n ? s.substring(0, n) : s;
}
