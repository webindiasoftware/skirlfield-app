import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../state/duty_state.dart';
import '../tracking/tracker.dart';
import 'attendance_screen.dart';
import 'coming_soon_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Bottom navigation, same tabs as the Stitch employee design.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;
  final _attendanceKey = GlobalKey<AttendanceScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<DutyState>().refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // back in the app: refresh today, upload queued points, and the profile if we started offline
      final auth = context.read<AuthState>();
      if (auth.offline) auth.loadMe().catchError((_) {});
      context.read<DutyState>().refresh();
      Tracker.instance.flush();
    }
  }

  void _go(int i) {
    setState(() => _tab = i);
    if (i == 1) _attendanceKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        HomeScreen(onOpenAttendance: () => _go(1)),
        AttendanceScreen(key: _attendanceKey),
        const ComingSoonScreen(
          title: 'Visits',
          icon: Icons.storefront_outlined,
          text: "Your customer visit plan, check-in at the customer's location and visit notes arrive in the next update.",
        ),
        const ComingSoonScreen(
          title: 'Expenses',
          icon: Icons.receipt_long_outlined,
          text: 'Travel allowance is calculated from your GPS distance. Claims, bills and approvals arrive in a later update.',
        ),
        const ProfileScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Visits'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
