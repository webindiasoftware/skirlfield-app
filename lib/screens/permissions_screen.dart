import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../tracking/permissions.dart';

/// Checklist for reliable background tracking. Re-checks when the user comes back from Settings.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  PermissionReport? _r;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final r = await Permissions.check();
    if (mounted) setState(() => _r = r);
  }

  Future<void> _do(Future<void> Function() f) async {
    await f();
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: const Text('Phone setup for tracking')),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text(
                r.allGood ? 'All set. Your route will be recorded even with the screen off.' : 'Fix the items below so your route (and travel allowance) is recorded correctly.',
                style: const TextStyle(color: AppColors.body, height: 1.4),
              ),
              const SizedBox(height: 16),
              PermissionTile(
                ok: r.serviceOn,
                title: 'Location is on',
                text: 'Phone location (GPS) must be switched on during duty.',
                action: 'Turn on',
                onFix: () => _do(Permissions.openLocationSettings),
              ),
              PermissionTile(
                ok: r.locationGranted,
                title: 'Location permission',
                text: 'SkirlField needs your location only while you are on duty.',
                action: 'Allow',
                onFix: () => _do(() async => Permissions.requestLocation()),
              ),
              PermissionTile(
                ok: r.always,
                optional: true,
                title: Platform.isIOS ? 'Location: Always' : 'Location: Allow all the time',
                text: Platform.isIOS
                    ? 'In Settings → SkirlField → Location choose "Always" so the route continues when the app is in the background.'
                    : 'On the next screen choose "Allow all the time". This keeps tracking if the phone closes the app.',
                action: 'Allow',
                onFix: r.locationGranted ? () => _do(() async => Permissions.requestLocation()) : null,
              ),
              if (Platform.isAndroid) ...[
                PermissionTile(
                  ok: r.notifications,
                  title: 'Notifications',
                  text: 'Shows the "On duty" notification while your route is recorded.',
                  action: 'Allow',
                  onFix: () => _do(Permissions.requestNotifications),
                ),
                PermissionTile(
                  ok: r.batteryUnrestricted,
                  title: 'Battery: unrestricted',
                  text: 'Stops the phone from pausing SkirlField to save battery.',
                  action: 'Allow',
                  onFix: () => _do(Permissions.requestBatteryUnrestricted),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    'Xiaomi, Redmi, Oppo, Vivo, Realme: also open Settings → Apps → SkirlField and turn on "Autostart", and set Battery saver to "No restrictions".',
                    style: TextStyle(color: AppColors.body, fontSize: 13.5, height: 1.4),
                  ),
                ),
                TextButton(onPressed: () => _do(Permissions.openAppSettings), child: const Text('Open app settings')),
              ],
            ]),
    );
  }
}

class PermissionTile extends StatelessWidget {
  const PermissionTile({super.key, required this.ok, required this.title, required this.text, required this.action, this.onFix, this.optional = false});
  final bool ok;
  final bool optional;
  final String title;
  final String text;
  final String action;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : (optional ? AppColors.warning : AppColors.danger);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(children: [
            Icon(ok ? Icons.check_circle : (optional ? Icons.error_outline : Icons.cancel_outlined), color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.3)),
              ]),
            ),
            if (!ok && onFix != null) TextButton(onPressed: onFix, child: Text(action)),
          ]),
        ),
      ),
    );
  }
}
