import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/device.dart';
import '../core/format.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import '../tracking/permissions.dart';
import '../tracking/tracker.dart';
import '../widgets/common.dart';
import 'change_password_screen.dart';
import 'permissions_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  PermissionReport? _perms;
  DeviceSnapshot? _device;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await Permissions.check();
    final d = await DeviceSnapshot.read();
    if (mounted) {
      setState(() {
        _perms = p;
        _device = d;
      });
    }
  }

  Future<void> _logout() async {
    if (Tracker.instance.running) {
      showSnack(context, 'End duty before signing out.', error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your password to sign in again. This phone stays registered to you.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(minimumSize: const Size(100, 44)), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true && mounted) await context.read<AuthState>().logout();
  }

  Widget _row(String label, String? value, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(value ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy))),
          if (trailing != null) trailing,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthState>().me!;
    final emp = me.employee;
    final p = _perms;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<AuthState>().loadMe();
          await _load();
        },
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                Avatar(initials(emp?.name ?? me.name), size: 64),
                const SizedBox(height: 10),
                Text(emp?.name ?? me.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
                Text([emp?.code, emp?.designation].whereType<String>().join(' · '), style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 6),
                Text(me.companyName, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SectionTitle('Work details'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(children: [
                _row('Branch', emp?.branch?.name),
                _row('Department', emp?.department),
                _row(
                  'Manager',
                  emp?.manager?.name,
                  trailing: emp?.manager?.phone == null
                      ? null
                      : IconButton(
                          tooltip: 'Call manager',
                          icon: const Icon(Icons.call_outlined, color: AppColors.primary),
                          onPressed: () => launchUrl(Uri(scheme: 'tel', path: emp!.manager!.phone)),
                        ),
                ),
                _row('Vehicle', emp?.defaultVehicle?.name),
                _row('Login', me.email ?? me.phone),
              ]),
            ),
          ),
          const SectionTitle('Phone & tracking'),
          Card(
            child: ListTile(
              leading: Icon(
                p == null ? Icons.hourglass_empty : (p.allGood ? Icons.verified_outlined : Icons.warning_amber_rounded),
                color: p == null ? AppColors.muted : (p.allGood ? AppColors.success : AppColors.warning),
              ),
              title: Text(p == null ? 'Checking…' : (p.allGood ? 'Ready for background tracking' : 'Setup needs attention'), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Location, notifications and battery settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PermissionsScreen()));
                _load();
              },
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(children: [
                _row('Phone', _device == null ? null : '${_device!.manufacturer} ${_device!.model}'.trim()),
                _row('System', _device?.osVersion),
                _row('App version', _device?.appVersion),
                _row('Server', Uri.parse(Config.apiBase).host),
              ]),
            ),
          ),
          const SectionTitle('Account'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Change password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: const Text('Sign out', style: TextStyle(color: AppColors.danger)),
                onTap: _logout,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
