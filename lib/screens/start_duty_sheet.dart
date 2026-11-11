import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../state/auth_state.dart';
import '../state/duty_state.dart';
import '../theme.dart';
import '../tracking/permissions.dart';
import '../widgets/common.dart';
import 'permissions_screen.dart';

/// Bottom sheet: permissions → vehicle → wait for a precise GPS fix → start.
Future<void> showStartDuty(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const StartDutySheet(),
    );

class StartDutySheet extends StatefulWidget {
  const StartDutySheet({super.key});

  @override
  State<StartDutySheet> createState() => _StartDutySheetState();
}

class _StartDutySheetState extends State<StartDutySheet> {
  PermissionReport? _perms;
  StreamSubscription<Position>? _sub;
  Position? _fix;
  int? _vehicleId;
  bool _busy = false;
  String? _gpsError;

  double get _need => context.read<DutyState>().today?.settings.maxAccuracyM ?? 50;
  bool get _fixGood => _fix != null && _fix!.accuracy <= _need;

  @override
  void initState() {
    super.initState();
    final duty = context.read<DutyState>();
    duty.loadVehicles();
    _vehicleId = context.read<AuthState>().me?.employee?.defaultVehicle?.id;
    _prepare();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    final p = await Permissions.check();
    if (!mounted) return;
    setState(() => _perms = p);
    if (p.canTrack) _watchGps();
  }

  void _watchGps() {
    _sub?.cancel();
    _gpsError = null;
    _sub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0)).listen(
      (p) {
        if (!mounted) return;
        // keep the best fix seen; a newer one replaces it if at least as good
        if (_fix == null || p.accuracy <= _fix!.accuracy || DateTime.now().difference(_fix!.timestamp).inSeconds > 20) {
          setState(() => _fix = p);
        }
      },
      onError: (Object e) {
        if (mounted) setState(() => _gpsError = 'GPS error: $e');
      },
    );
  }

  Future<void> _fixPermissions() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PermissionsScreen()));
    await _prepare();
  }

  Future<void> _start() async {
    final fix = _fix;
    if (fix == null) return;
    setState(() => _busy = true);
    // geolocator shares one location stream per app: release ours so the tracker can open its
    // own with the "On duty" foreground notification
    await _sub?.cancel();
    _sub = null;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    try {
      final late = await context.read<DutyState>().startDuty(fix: fix, vehicleId: _vehicleId);
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, late > 0 ? 'Duty started at ${fmtTime(DateTime.now())} — $late min after shift start.' : 'Duty started. Have a good day!');
    } on ApiException catch (e) {
      if (mounted) {
        showError(context, e);
        _watchGps(); // keep showing the GPS state for another try
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duty = context.watch<DutyState>();
    final p = _perms;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 16),
        const Text('Start duty', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy)),
        const SizedBox(height: 4),
        const Text('Your route is recorded from now until you end duty.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 18),
        if (p == null)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
        else if (!p.canTrack) ...[
          Banner2(
            text: !p.serviceOn ? 'Location is turned off on this phone.' : 'SkirlField is not allowed to use your location.',
            icon: Icons.location_off_outlined,
            color: AppColors.danger,
            soft: AppColors.dangerSoft,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _fixPermissions, child: const Text('Fix location settings')),
        ] else ...[
          if (!p.allGood) ...[
            Banner2(
              text: 'Tracking may stop when the screen is off. Finish the phone setup for reliable distance.',
              action: 'Fix',
              onAction: _fixPermissions,
            ),
            const SizedBox(height: 14),
          ],
          const Text('Vehicle', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 8),
          if (duty.vehicles.isEmpty)
            const Text('Your default vehicle will be used.', style: TextStyle(color: AppColors.muted))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final v in duty.vehicles)
                ChoiceChip(
                  label: Text(v.name),
                  selected: _vehicleId == v.id,
                  onSelected: (_) => setState(() => _vehicleId = v.id),
                ),
            ]),
          const SizedBox(height: 18),
          _GpsStatus(fix: _fix, need: _need, error: _gpsError),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy || !_fixGood ? null : _start,
            icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.play_arrow_rounded),
            label: Text(_fixGood ? 'Start duty' : 'Waiting for precise location…'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
          ),
        ],
      ]),
    );
  }
}

class _GpsStatus extends StatelessWidget {
  const _GpsStatus({required this.fix, required this.need, this.error});
  final Position? fix;
  final double need;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final good = fix != null && fix!.accuracy <= need;
    final color = good ? AppColors.success : AppColors.warning;
    final text = error ??
        (fix == null
            ? 'Finding your location…'
            : good
                ? 'Location ready (±${fix!.accuracy.round()} m)'
                : 'Getting a precise location: ±${fix!.accuracy.round()} m, need ±${need.round()} m. Step outdoors or near a window.');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: good ? AppColors.successSoft : AppColors.warningSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        if (good)
          Icon(Icons.gps_fixed, color: color)
        else
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.body, height: 1.35))),
      ]),
    );
  }
}
