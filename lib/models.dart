/// Plain models for the API responses the app uses.

int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

class Ref {
  Ref(this.id, this.name, [this.phone]);
  final int id;
  final String name;
  final String? phone;
  static Ref? from(dynamic v) => v is Map ? Ref(_i(v['id']), '${v['name'] ?? ''}', v['phone'] as String?) : null;
}

class Employee {
  Employee(this.json);
  final Map<String, dynamic> json;
  int get id => _i(json['id']);
  String get code => '${json['code'] ?? ''}';
  String get name => '${json['name'] ?? ''}';
  String? get designation => json['designation'] as String?;
  String? get department => json['department'] as String?;
  Ref? get branch => Ref.from(json['branch']);
  Ref? get manager => Ref.from(json['manager']);
  Ref? get defaultVehicle => Ref.from(json['default_vehicle']);
  bool get isFieldEmployee => json['is_field_employee'] == true;
  bool get trackingEnabled => json['tracking_enabled'] == true;
}

class Me {
  Me(this.json);
  final Map<String, dynamic> json;
  Map<String, dynamic> get user => _m(json['user']);
  String get name => '${user['name'] ?? ''}';
  String? get email => user['email'] as String?;
  String? get phone => user['phone'] as String?;
  bool get mustChangePassword => user['must_change_password'] == true;
  bool get isPlatform => user['type'] == 'PLATFORM';
  Map<String, dynamic> get permissions => _m(json['permissions']);
  bool can(String p) => permissions.containsKey(p);
  Map<String, dynamic> get company => _m(json['company']);
  String get companyName => '${company['name'] ?? ''}';
  bool get readOnly => company['read_only'] == true;
  Employee? get employee => json['employee'] is Map ? Employee(_m(json['employee'])) : null;
  Map<String, dynamic> get settings => _m(json['settings']);
  int? get deviceId => json['device_id'] == null ? null : _i(json['device_id']);

  /// Can use duty tracking from this phone.
  bool get canDoDuty => can('duty.self') && (employee?.isFieldEmployee ?? false) && (employee?.trackingEnabled ?? false);
}

/// GPS / duty settings sent by the server (company settings).
class TrackingSettings {
  TrackingSettings(this.raw);
  final Map<String, dynamic> raw;
  num _n(String k, num def) => raw[k] is num ? raw[k] as num : (num.tryParse('${raw[k]}') ?? def);

  int get intervalMovingS => _n('gps.interval_moving_s', 30).toInt();
  int get intervalStationaryS => _n('gps.interval_stationary_s', 120).toInt();
  int get minMoveM => _n('gps.min_move_m', 25).toInt();
  double get maxAccuracyM => _n('gps.max_accuracy_m', 50).toDouble();
  int get batchSize => _n('gps.batch_size', 20).toInt();
  int get batchMaxWaitS => _n('gps.batch_max_wait_s', 120).toInt();
  int get heartbeatS => _n('gps.heartbeat_s', 300).toInt();
  bool get pauseEnabled => raw['duty.pause_enabled'] != false;
  int get maxPauses => _n('duty.max_pauses', 2).toInt();
  int get maxPauseMin => _n('duty.max_pause_min', 60).toInt();

  static TrackingSettings from(dynamic v) => TrackingSettings(_m(v));
}

class DutySession {
  DutySession(this.json);
  final Map<String, dynamic> json;
  int get id => _i(json['id']);
  String get businessDate => '${json['business_date'] ?? ''}';
  String get status => '${json['status'] ?? ''}';
  bool get isOpen => status == 'ACTIVE' || status == 'PAUSED';
  bool get isPaused => status == 'PAUSED';
  int? get vehicleTypeId => json['vehicle_type_id'] == null ? null : _i(json['vehicle_type_id']);
  DateTime? get startAt => DateTime.tryParse('${json['start_at']}')?.toLocal();
  DateTime? get endAt => json['end_at'] == null ? null : DateTime.tryParse('${json['end_at']}')?.toLocal();
  String? get endSource => json['end_source'] as String?;
  int get pausedSeconds => _i(json['paused_seconds']);
  int? get workedSeconds => json['worked_seconds'] == null ? null : _i(json['worked_seconds']);
  double get gpsKm => _d(json['gps_distance_km']);
  double get gapKm => _d(json['gap_distance_km']);
  bool get mockDetected => json['mock_detected'] == true;
  double? get startLat => json['start'] is Map ? _d((json['start'] as Map)['lat']) : null;
  double? get startLng => json['start'] is Map ? _d((json['start'] as Map)['lng']) : null;

  /// Worked so far (open session counts up to now; pauses excluded up to the last refresh).
  int workedNow({int openPauseSeconds = 0}) {
    if (workedSeconds != null && !isOpen) return workedSeconds!;
    final s = startAt;
    if (s == null) return 0;
    return DateTime.now().difference(s).inSeconds - pausedSeconds - openPauseSeconds;
  }
}

class Today {
  Today(this.json);
  final Map<String, dynamic> json;
  String get businessDate => '${json['business_date'] ?? ''}';
  String? get dayStatus => json['day_status'] as String?;
  DutySession? get open => json['open_session'] is Map ? DutySession(_m(json['open_session'])) : null;
  List<DutySession> get sessions => (json['sessions'] as List? ?? []).map((e) => DutySession(_m(e))).toList();
  double get todayKm => _d(json['today_km']);
  Map<String, dynamic> get shift => _m(json['shift']);
  String get shiftStart => '${shift['start'] ?? ''}';
  String get shiftEnd => '${shift['end'] ?? ''}';
  TrackingSettings get settings => TrackingSettings.from(json['tracking_settings']);
}

class AttendanceDay {
  AttendanceDay(this.json);
  final Map<String, dynamic> json;
  String get date => '${json['date']}';
  DateTime get day => DateTime.parse(date);
  String get status => '${json['status'] ?? ''}';
  DateTime? get firstIn => json['first_in_at'] == null ? null : DateTime.tryParse('${json['first_in_at']}')?.toLocal();
  DateTime? get lastOut => json['last_out_at'] == null ? null : DateTime.tryParse('${json['last_out_at']}')?.toLocal();
  int get workedSeconds => _i(json['worked_seconds']);
  int get lateMinutes => _i(json['late_minutes']);
  double get km => _d(json['gps_km']);
  bool get isCorrected => json['is_corrected'] == true;
  List<DutySession> get sessions => (json['sessions'] as List? ?? []).map((e) => DutySession(_m(e))).toList();
}

class Correction {
  Correction(this.json);
  final Map<String, dynamic> json;
  int get id => _i(json['id']);
  String get businessDate => '${json['business_date']}';
  String get type => '${json['correction_type']}';
  String get status => '${json['status']}';
  String get reason => '${json['reason'] ?? ''}';
  String? get reviewNote => json['review_note'] as String?;
  String? get reviewedBy => json['reviewed_by_name'] as String?;
  String? get requestedStatus => json['requested_status'] as String?;
  DateTime? get requestedStart => json['requested_start_at'] == null ? null : DateTime.tryParse('${json['requested_start_at']}')?.toLocal();
  DateTime? get requestedEnd => json['requested_end_at'] == null ? null : DateTime.tryParse('${json['requested_end_at']}')?.toLocal();
}

class Vehicle {
  Vehicle(this.id, this.name);
  final int id;
  final String name;
}
