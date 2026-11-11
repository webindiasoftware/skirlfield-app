/// Small formatting helpers (no intl dependency). Times are shown in the phone's local time zone.

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

DateTime? parseIso(String? s) => (s == null || s.isEmpty) ? null : DateTime.tryParse(s)?.toLocal();

String fmtTime(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'AM' : 'PM'}';
}

String fmtTimeIso(String? s) => fmtTime(parseIso(s));

/// 11 Nov 2026
String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Wed, 11 Nov
String fmtDayShort(DateTime d) => '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

String fmtMonth(int year, int month) => '${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][month - 1]} $year';

/// "2h 05m", "45m"
String fmtDuration(int seconds) {
  if (seconds < 0) seconds = 0;
  final m = (seconds / 60).round();
  if (m < 60) return '${m}m';
  return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
}

String fmtKm(num km, {int digits = 1}) => '${km.toStringAsFixed(digits)} km';

/// YYYY-MM-DD of a local date
String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// HH:MM (24 h) for the API
String hhmm(int hour, int minute) => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

String ago(DateTime? d) {
  if (d == null) return 'never';
  final s = DateTime.now().difference(d).inSeconds;
  if (s < 60) return 'just now';
  if (s < 3600) return '${s ~/ 60} min ago';
  if (s < 86400) return '${s ~/ 3600} h ago';
  return '${s ~/ 86400} d ago';
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
  return parts.map((p) => p[0].toUpperCase()).join();
}
