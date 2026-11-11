import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../core/api.dart';
import '../core/device.dart';
import '../models.dart';
import 'permissions.dart';
import 'point_queue.dart';

/// Records the route while on duty.
///
/// * Android: geolocator runs a foreground service with an "On duty" notification, so tracking
///   continues with the screen off. iOS: background location updates (blue indicator).
/// * The phone filters first (bad accuracy dropped, stationary points thinned); the server re-checks every
///   point and alone decides the distance.
/// * Points go to an on-phone queue and are uploaded in batches; nothing is lost without network.
class Tracker extends ChangeNotifier {
  Tracker._();
  static final Tracker instance = Tracker._();

  final _battery = Battery();
  final _uuid = const Uuid();

  int? sessionId;
  TrackingSettings settings = TrackingSettings({});
  bool running = false; // a duty is being tracked (also true while paused)
  bool paused = false;

  Position? lastFix; // newest fix from the phone (even if not kept)
  DateTime? lastKeptAt;
  Position? _lastKept;
  DateTime? lastUploadAt;
  String? uploadError;
  String? gpsProblem;
  int pending = 0;
  double? serverKm; // session distance as last confirmed by the server
  int? batteryPct;

  StreamSubscription<Position>? _sub;
  Timer? _tick;
  DateTime _lastHeartbeat = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastUploadTry = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _nextRetry = DateTime.fromMillisecondsSinceEpoch(0);
  bool _uploading = false;

  // ------------------------------------------------------------------ lifecycle

  /// Called after start-duty, and on app launch when the server says a duty is still open.
  Future<void> start(int sessionId, TrackingSettings s, {bool paused = false}) async {
    if (running && this.sessionId == sessionId) {
      settings = s;
      if (paused && !this.paused) {
        await pause();
      } else if (!paused && this.paused) {
        await resume();
      }
      return;
    }
    if (running) await stop();
    this.sessionId = sessionId;
    settings = s;
    running = true;
    this.paused = paused;
    _lastKept = null;
    lastKeptAt = null;
    gpsProblem = null;
    await PointQueue.setMeta('active_session', '$sessionId');
    await PointQueue.setMeta('active_settings', jsonEncode(s.raw));
    await PointQueue.setMeta('active_paused', paused ? '1' : null);
    if (!paused) await _listen();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => _onTick());
    pending = await PointQueue.count();
    notifyListeners();
    unawaited(_heartbeat());
  }

  Future<void> pause() async {
    paused = true;
    await PointQueue.setMeta('active_paused', '1');
    await _sub?.cancel();
    _sub = null;
    notifyListeners();
    unawaited(flush());
  }

  Future<void> resume() async {
    paused = false;
    await PointQueue.setMeta('active_paused', null);
    _lastKept = null; // first point after a pause is always kept
    await _listen();
    notifyListeners();
  }

  /// End of duty: stop recording, then push whatever is still queued.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _tick?.cancel();
    _tick = null;
    running = false;
    paused = false;
    sessionId = null;
    await PointQueue.setMeta('active_session', null);
    await PointQueue.setMeta('active_settings', null);
    await PointQueue.setMeta('active_paused', null);
    notifyListeners();
    unawaited(flush());
  }

  /// App launch, before the network answers: keep recording the duty that was running when the app was closed.
  Future<void> resumeFromDisk() async {
    final sid = int.tryParse(await PointQueue.getMeta('active_session') ?? '');
    if (sid == null || running) return;
    final raw = await PointQueue.getMeta('active_settings');
    final s = raw != null ? TrackingSettings(Map<String, dynamic>.from(jsonDecode(raw) as Map)) : TrackingSettings({});
    final wasPaused = (await PointQueue.getMeta('active_paused')) == '1';
    final perms = await Permissions.check();
    if (perms.canTrack) await start(sid, s, paused: wasPaused);
  }

  /// App launch: match the phone to the server's view of today.
  Future<void> restore(Today today) async {
    final open = today.open;
    if (open != null) {
      serverKm = open.gpsKm;
      if (!running || sessionId != open.id || paused != open.isPaused) {
        final perms = await Permissions.check();
        if (perms.canTrack) {
          await start(open.id, today.settings, paused: open.isPaused);
        } else {
          gpsProblem = 'Location permission is off. Allow it to keep recording your route.';
          notifyListeners();
        }
      }
    } else if (running) {
      await stop();
    }
    pending = await PointQueue.count();
    notifyListeners();
    if (pending > 0) unawaited(flush());
  }

  // ------------------------------------------------------------------ location

  LocationSettings _locationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: Duration(seconds: settings.intervalMovingS.clamp(5, 120)),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'SkirlField · On duty',
          notificationText: 'Recording your route for travel allowance. End duty in the app to stop.',
          notificationChannelName: 'Duty tracking',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
  }

  Future<void> _listen() async {
    await _sub?.cancel();
    try {
      _sub = Geolocator.getPositionStream(locationSettings: _locationSettings()).listen(
        _onPosition,
        onError: (Object e) {
          gpsProblem = e is LocationServiceDisabledException
              ? 'Location is turned off. Turn it on to keep recording.'
              : 'GPS stopped: $e';
          _sub = null;
          notifyListeners();
        },
        cancelOnError: true,
      );
    } catch (e) {
      gpsProblem = 'Could not start GPS: $e';
      notifyListeners();
    }
  }

  Future<void> _onPosition(Position p) async {
    final sid = sessionId;
    if (sid == null || paused) return;
    lastFix = p;
    gpsProblem = null;
    if (!_keep(p)) {
      notifyListeners();
      return;
    }
    _lastKept = p;
    lastKeptAt = DateTime.now();
    final seq = await PointQueue.nextSeq();
    await PointQueue.add(sid, _payload(p, seq));
    pending++;
    notifyListeners();
    if (pending >= settings.batchSize) unawaited(flush());
  }

  bool _keep(Position p) {
    if (p.isMocked) return true; // the server must see these
    if (p.accuracy > settings.maxAccuracyM) return false; // too vague to be useful
    final last = _lastKept;
    if (last == null) return true;
    final moved = Geolocator.distanceBetween(last.latitude, last.longitude, p.latitude, p.longitude);
    final secs = p.timestamp.difference(last.timestamp).inSeconds;
    return moved >= settings.minMoveM || secs >= settings.intervalStationaryS;
  }

  Map<String, dynamic> _payload(Position p, int seq) {
    double? clampOrNull(double v, double lo, double hi) => (v.isNaN || v < lo || v > hi) ? null : v;
    final heading = p.heading.isNaN || p.heading < 0 ? null : p.heading.round() % 361;
    return {
      'client_point_id': _uuid.v4(),
      'seq': seq,
      'lat': double.parse(p.latitude.toStringAsFixed(7)),
      'lng': double.parse(p.longitude.toStringAsFixed(7)),
      'accuracy_m': clampOrNull(p.accuracy, 0, 100000),
      'speed_kmh': p.speed >= 0 ? clampOrNull(p.speed * 3.6, 0, 2000) : null,
      'bearing': heading,
      'altitude_m': p.altitude == 0 ? null : clampOrNull(p.altitude, -1000, 10000),
      'provider': Platform.isIOS ? 'GPS' : 'FUSED',
      'is_mock': p.isMocked,
      'battery_pct': (batteryPct != null && batteryPct! >= 0 && batteryPct! <= 100) ? batteryPct : null,
      'recorded_at': p.timestamp.toUtc().toIso8601String(),
    };
  }

  // ------------------------------------------------------------------ upload + heartbeat

  Future<void> _onTick() async {
    final now = DateTime.now();
    if (_lastHeartbeat.add(Duration(seconds: settings.heartbeatS)).isBefore(now)) {
      unawaited(_heartbeat());
    }
    if (pending > 0 && now.isAfter(_nextRetry) && (pending >= settings.batchSize || now.difference(_lastUploadTry).inSeconds >= settings.batchMaxWaitS)) {
      unawaited(flush());
    }
    // stream died (location switched off and on again): try again
    if (running && !paused && _sub == null) {
      final perms = await Permissions.check();
      if (perms.canTrack) await _listen();
    }
  }

  /// Uploads everything queued, oldest first. Safe to call any time; the server ignores duplicates.
  Future<void> flush() async {
    if (_uploading) return;
    _uploading = true;
    _lastUploadTry = DateTime.now();
    try {
      while (true) {
        final batch = await PointQueue.oldest(limit: 300);
        if (batch.isEmpty) break;
        try {
          final r = await Api.instance.post('/tracking/location-batch', {
            'session_id': batch.first.sessionId,
            'batch_id': _uuid.v4(),
            'points': batch.map((q) => q.payload).toList(),
          }) as Map;
          await PointQueue.remove(batch.map((q) => q.id).toList());
          final s = r['session'];
          if (s is Map && batch.first.sessionId == sessionId) serverKm = (s['gps_distance_km'] as num?)?.toDouble();
          lastUploadAt = DateTime.now();
          uploadError = null;
        } on ApiException catch (e) {
          if (e.isNetwork || e.status >= 500 || e.status == 429 || e.status == 401) {
            uploadError = e.isNetwork ? 'Offline — points are saved on the phone' : e.message;
            _nextRetry = DateTime.now().add(const Duration(seconds: 60));
            break;
          }
          // the server will never accept this batch (e.g. session not found): drop it so the queue moves on
          await PointQueue.remove(batch.map((q) => q.id).toList());
          uploadError = e.message;
        }
        if (batch.length < 300) break;
      }
    } finally {
      pending = await PointQueue.count();
      _uploading = false;
      notifyListeners();
    }
  }

  Future<void> _heartbeat() async {
    _lastHeartbeat = DateTime.now();
    try {
      batteryPct = await _battery.batteryLevel;
    } catch (_) {}
    try {
      final perms = await Permissions.check();
      final dev = await DeviceSnapshot.read();
      await Api.instance.post('/tracking/heartbeat', {
        if (sessionId != null) 'session_id': sessionId,
        if (lastFix != null) 'lat': lastFix!.latitude,
        if (lastFix != null) 'lng': lastFix!.longitude,
        if (batteryPct != null && batteryPct! >= 0 && batteryPct! <= 100) 'battery_pct': batteryPct,
        'gps_enabled': perms.serviceOn,
        'location_permission': perms.apiValue,
        if (Platform.isAndroid) 'battery_optimisation': !perms.batteryUnrestricted,
        'app_version': dev.appVersion,
      });
    } catch (_) {
      // heartbeats are best effort
    }
  }
}
