import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// What the phone allows right now, for the checklist on the Profile and start-duty screens.
class PermissionReport {
  PermissionReport({required this.serviceOn, required this.location, required this.notifications, required this.batteryUnrestricted});

  final bool serviceOn;
  final LocationPermission location;
  final bool notifications;
  final bool batteryUnrestricted;

  bool get locationGranted => location == LocationPermission.always || location == LocationPermission.whileInUse;
  bool get always => location == LocationPermission.always;

  /// Minimum to start duty.
  bool get canTrack => serviceOn && locationGranted;

  /// Everything set up for reliable tracking with the screen off.
  bool get allGood => canTrack && always && notifications && batteryUnrestricted;

  /// Value for the heartbeat's location_permission field.
  String get apiValue => location == LocationPermission.always
      ? 'ALWAYS'
      : location == LocationPermission.whileInUse
          ? 'WHILE_IN_USE'
          : 'DENIED';
}

class Permissions {
  static Future<PermissionReport> check() async {
    final service = await Geolocator.isLocationServiceEnabled();
    final loc = await Geolocator.checkPermission();
    var notif = true;
    var battery = true;
    if (Platform.isAndroid) {
      notif = await ph.Permission.notification.isGranted;
      battery = await ph.Permission.ignoreBatteryOptimizations.isGranted;
    }
    return PermissionReport(serviceOn: service, location: loc, notifications: notif, batteryUnrestricted: battery);
  }

  /// First call asks "while using the app"; called again on Android 10+ it asks for "Allow all the time"
  /// (Android 11+ opens the settings page for that).
  static Future<LocationPermission> requestLocation() async {
    final current = await Geolocator.checkPermission();
    if (current == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return Geolocator.checkPermission();
    }
    return Geolocator.requestPermission();
  }

  static Future<void> requestNotifications() async {
    if (!Platform.isAndroid) return;
    final s = await ph.Permission.notification.request();
    if (s.isPermanentlyDenied) await ph.openAppSettings();
  }

  static Future<void> requestBatteryUnrestricted() async {
    if (!Platform.isAndroid) return;
    await ph.Permission.ignoreBatteryOptimizations.request();
  }

  static Future<void> openLocationSettings() => Geolocator.openLocationSettings();
  static Future<void> openAppSettings() => Geolocator.openAppSettings();
}
