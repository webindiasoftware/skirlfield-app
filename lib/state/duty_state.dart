import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../core/api.dart';
import '../models.dart';
import '../tracking/point_queue.dart';
import '../tracking/tracker.dart';

/// Today's duty for the signed-in field employee, and the duty actions.
class DutyState extends ChangeNotifier {
  Today? today;
  bool loading = false;
  ApiException? error;

  /// Set when duty is not available for this login (not a field employee, tracking off, ...).
  ApiException? blocked;
  List<Vehicle> vehicles = [];

  final _tracker = Tracker.instance;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      await _sendPendingEnd();
      final j = await Api.instance.get('/attendance/today') as Map;
      today = Today(Map<String, dynamic>.from(j));
      error = null;
      blocked = null;
      await _tracker.restore(today!);
    } on ApiException catch (e) {
      if (e.status == 403) {
        blocked = e;
      } else {
        error = e;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadVehicles() async {
    if (vehicles.isNotEmpty) return;
    try {
      final p = await Api.instance.getPage('/masters/vehicle-types', query: {'is_active': 1, 'per_page': 100});
      vehicles = p.items.map((v) => Vehicle((v['id'] as num).toInt(), '${v['name']}')).toList();
      notifyListeners();
    } catch (_) {
      // the server falls back to the employee's default vehicle
    }
  }

  // ------------------------------------------------------------------ actions

  /// Returns late minutes (0 when on time).
  Future<int> startDuty({required Position fix, int? vehicleId, String? address}) async {
    int? battery;
    try {
      battery = await Battery().batteryLevel;
    } catch (_) {}
    // same id on a retry, so a lost response never creates two duties
    final idem = await PointQueue.getMeta('start_idem') ?? const Uuid().v4();
    await PointQueue.setMeta('start_idem', idem);
    final r = await Api.instance.post('/attendance/start-duty', {
      'lat': fix.latitude,
      'lng': fix.longitude,
      'accuracy_m': fix.accuracy,
      if (vehicleId != null) 'vehicle_type_id': vehicleId,
      if (battery != null && battery >= 0 && battery <= 100) 'battery_pct': battery,
      if (address != null) 'address': address,
      'started_at': fix.timestamp.toUtc().toIso8601String(),
      'client_session_id': idem,
    }) as Map;
    await PointQueue.setMeta('start_idem', null);
    final session = DutySession(Map<String, dynamic>.from(r['session'] as Map));
    await _tracker.start(session.id, TrackingSettings.from(r['tracking_settings'] ?? today?.settings.raw));
    _tracker.serverKm = session.gpsKm;
    await refresh();
    return (r['late_minutes'] as num?)?.toInt() ?? 0;
  }

  Future<void> pauseDuty(String reason) async {
    final fix = await _quickFix();
    await Api.instance.post('/attendance/pause', {
      'reason': reason,
      if (fix != null) 'lat': fix.latitude,
      if (fix != null) 'lng': fix.longitude,
    });
    await _tracker.pause();
    await refresh();
  }

  Future<void> resumeDuty() async {
    await Api.instance.post('/attendance/resume', {});
    await _tracker.resume();
    await refresh();
  }

  /// Ends duty. Without network the end is saved on the phone and sent later (the server accepts it up to 24 h late).
  /// Returns false when it was saved for later.
  Future<bool> endDuty() async {
    final open = today?.open;
    if (open == null) return true;
    await _tracker.flush();
    final fix = await _quickFix();
    final body = {
      'session_id': open.id,
      'lat': fix?.latitude ?? open.startLat,
      'lng': fix?.longitude ?? open.startLng,
      if (fix != null) 'accuracy_m': fix.accuracy,
      'ended_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      await Api.instance.post('/attendance/end-duty', body);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      await PointQueue.setMeta('pending_end', jsonEncode(body));
      await _tracker.stop();
      notifyListeners();
      return false;
    }
    await _tracker.stop();
    await refresh();
    return true;
  }

  Future<bool> hasPendingEnd() async => (await PointQueue.getMeta('pending_end')) != null;

  Future<void> _sendPendingEnd() async {
    final raw = await PointQueue.getMeta('pending_end');
    if (raw == null) return;
    try {
      await _tracker.flush();
      await Api.instance.post('/attendance/end-duty', jsonDecode(raw));
      await PointQueue.setMeta('pending_end', null);
    } on ApiException catch (e) {
      // NOT_ON_DUTY: already closed (by HR or the auto-close); anything else but network: give up
      if (!e.isNetwork) await PointQueue.setMeta('pending_end', null);
    }
  }

  Future<Position?> _quickFix() async {
    final last = _tracker.lastFix;
    if (last != null && DateTime.now().difference(last.timestamp).inMinutes < 2) return last;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
    } catch (_) {
      return last ?? await Geolocator.getLastKnownPosition();
    }
  }

  /// Worked seconds today including an open duty (pauses so far excluded).
  int workedToday() {
    final t = today;
    if (t == null) return 0;
    var total = 0;
    for (final s in t.sessions) {
      total += s.isOpen ? s.workedNow() : (s.workedSeconds ?? 0);
    }
    return total < 0 ? 0 : total;
  }

  /// Today's km: closed duties from the server + the open one as last confirmed by an upload.
  double kmToday() {
    final t = today;
    if (t == null) return 0;
    final open = t.open;
    if (open == null) return t.todayKm;
    final live = _tracker.serverKm ?? open.gpsKm;
    return t.todayKm - open.gpsKm + (live > open.gpsKm ? live : open.gpsKm);
  }
}
