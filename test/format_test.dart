import 'package:flutter_test/flutter_test.dart';
import 'package:skirlfield_app/core/format.dart';

void main() {
  test('durations', () {
    expect(fmtDuration(45 * 60), '45m');
    expect(fmtDuration(2 * 3600 + 5 * 60), '2h 05m');
  });

  test('api helpers', () {
    expect(hhmm(9, 5), '09:05');
    expect(ymd(DateTime(2026, 11, 3)), '2026-11-03');
    expect(initials('Rahul Kumar Sharma'), 'RK');
  });
}
