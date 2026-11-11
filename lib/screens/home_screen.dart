import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../models.dart';
import '../state/auth_state.dart';
import '../state/duty_state.dart';
import '../theme.dart';
import '../tracking/tracker.dart';
import '../widgets/common.dart';
import 'permissions_screen.dart';
import 'start_duty_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenAttendance});
  final VoidCallback onOpenAttendance;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // the "time on duty" figure counts up while the screen is open
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final duty = context.watch<DutyState>();
    final tracker = context.watch<Tracker>();
    final me = auth.me!;
    final emp = me.employee;
    final today = duty.today;
    final open = today?.open;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(me.companyName.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.muted, fontWeight: FontWeight.w600)),
          const Text('Dashboard'),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StatusChip(open == null ? 'OFF_DUTY' : open.status, label: open == null ? 'Off duty' : (open.isPaused ? 'Paused' : '● Live')),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await duty.refresh();
          await tracker.flush();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (auth.offline) ...[
              const Banner2(text: 'No internet. Your route is still recorded and will upload when you are back online.', icon: Icons.cloud_off_outlined),
              const SizedBox(height: 12),
            ],
            // ------------------------------------------------ greeting
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Avatar(initials(emp?.name ?? me.name), dot: open == null ? AppColors.muted : (open.isPaused ? AppColors.purple : AppColors.success)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${_greeting()}, ${(emp?.name ?? me.name).split(' ').first}!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
                      const SizedBox(height: 2),
                      Text([emp?.code, emp?.designation].whereType<String>().join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
                      if (today != null && today.shiftStart.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.schedule, size: 15, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(open != null ? 'Started at ${fmtTime(open.startAt)}' : 'Shift ${today.shiftStart} – ${today.shiftEnd}', style: const TextStyle(fontSize: 13, color: AppColors.body)),
                        ]),
                      ],
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // ------------------------------------------------ duty card
            if (duty.blocked != null)
              _BlockedCard(error: duty.blocked!)
            else if (today == null && duty.loading)
              const Card(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())))
            else if (today == null && duty.error != null)
              _ErrorCard(error: duty.error!, onRetry: duty.refresh)
            else if (today != null)
              _DutyCard(today: today, tracker: tracker),

            if (tracker.gpsProblem != null) ...[
              const SizedBox(height: 12),
              Banner2(
                text: tracker.gpsProblem!,
                icon: Icons.location_off_outlined,
                color: AppColors.danger,
                soft: AppColors.dangerSoft,
                action: 'Fix',
                onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PermissionsScreen())),
              ),
            ],

            // ------------------------------------------------ stats
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Stat(icon: Icons.two_wheeler, label: "Today's travel", value: duty.kmToday().toStringAsFixed(1), unit: 'km', sub: open != null ? 'GPS, updates every few minutes' : 'GPS distance')),
              const SizedBox(width: 12),
              Expanded(child: _Stat(icon: Icons.timer_outlined, label: 'Time on duty', value: fmtDuration(duty.workedToday()), sub: today?.sessions.isNotEmpty == true ? '${today!.sessions.length} dut${today.sessions.length == 1 ? 'y' : 'ies'} today' : 'Not started')),
            ]),
            const SizedBox(height: 12),
            const Row(children: [
              Expanded(child: _Stat(icon: Icons.storefront_outlined, label: 'Visits', value: '—', sub: 'Coming soon', muted: true)),
              SizedBox(width: 12),
              Expanded(child: _Stat(icon: Icons.receipt_long_outlined, label: 'TA estimate', value: '—', sub: 'Coming soon', muted: true)),
            ]),

            // ------------------------------------------------ quick actions
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Action(icon: Icons.calendar_month_outlined, label: 'My attendance', onTap: widget.onOpenAttendance)),
              const SizedBox(width: 10),
              Expanded(child: _Action(icon: Icons.phone_in_talk_outlined, label: 'Call manager', onTap: emp?.manager?.phone == null ? null : () => launchUrl(Uri(scheme: 'tel', path: emp!.manager!.phone)))),
              const SizedBox(width: 10),
              Expanded(child: _Action(icon: Icons.health_and_safety_outlined, label: 'Phone setup', onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PermissionsScreen())))),
            ]),

            // ------------------------------------------------ today's duties
            if (today != null && today.sessions.isNotEmpty) ...[
              const SectionTitle("Today's duties"),
              for (final s in today.sessions) _SessionTile(s: s),
            ],
          ],
        ),
      ),
    );
  }
}

class _DutyCard extends StatelessWidget {
  const _DutyCard({required this.today, required this.tracker});
  final Today today;
  final Tracker tracker;

  Future<void> _pause(BuildContext context) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Pause duty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 4),
            Text('GPS stops while paused. Allowed: ${today.settings.maxPauses} pauses, ${today.settings.maxPauseMin} min each.', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            for (final r in const ['Lunch', 'Tea break', 'Personal', 'Vehicle problem'])
              ListTile(title: Text(r), leading: const Icon(Icons.pause_circle_outline), onTap: () => Navigator.pop(c, r)),
          ]),
        ),
      ),
    );
    if (reason == null || !context.mounted) return;
    await _run(context, () => context.read<DutyState>().pauseDuty(reason), 'Duty paused. Resume when you are back on the road.');
  }

  Future<void> _end(BuildContext context) async {
    final duty = context.read<DutyState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('End duty?'),
        content: Text('Today so far: ${duty.kmToday().toStringAsFixed(1)} km, ${fmtDuration(duty.workedToday())} on duty.\n\nGPS stops and your day is calculated. You can start again later if needed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep working')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(110, 44)),
            child: const Text('End duty'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final sent = await duty.endDuty();
      if (context.mounted) {
        showSnack(context, sent ? 'Duty ended. Thanks for today!' : 'No internet: duty end is saved and will be sent automatically.');
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _run(BuildContext context, Future<void> Function() f, String done) async {
    try {
      await f();
      if (context.mounted) showSnack(context, done);
    } on ApiException catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = today.open;
    final fix = tracker.lastFix;
    final busy = context.watch<DutyState>().loading;

    if (open == null) {
      final status = today.dayStatus;
      final ended = today.sessions.isNotEmpty;
      return _NavyCard(children: [
        Text(ended ? 'Duty ended for now' : 'Ready to start your day?', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          status == 'WEEK_OFF'
              ? 'Today is your week off. Start duty only if you are working.'
              : status == 'HOLIDAY'
                  ? 'Today is a holiday. Start duty only if you are working.'
                  : ended
                      ? 'Start again if you go back to the field.'
                      : 'Start duty when you leave for your first visit. Your GPS route is recorded until you end duty.',
          style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.35),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: busy ? null : () => showStartDuty(context),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(ended ? 'Start duty again' : 'Start duty'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
        ),
        if (tracker.pending > 0) ...[
          const SizedBox(height: 10),
          Text('${tracker.pending} GPS points waiting to upload', style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 12.5)),
        ],
      ]);
    }

    final paused = open.isPaused;
    final syncText = tracker.pending == 0
        ? 'Live'
        : (tracker.uploadError != null ? '${tracker.pending} waiting' : '${tracker.pending} queued');
    return _NavyCard(children: [
      Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: paused ? const Color(0xFFA78BFA) : const Color(0xFF4ADE80), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(paused ? 'Duty paused' : 'GPS tracking active', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
        if (fix != null && !paused) Text('Acc ±${fix.accuracy.round()} m', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5)),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        _Metric(label: 'Speed', value: paused || fix == null ? '—' : '${(fix.speed < 0 ? 0 : fix.speed * 3.6).round()}', unit: 'km/h'),
        _Metric(label: 'Battery', value: tracker.batteryPct != null && tracker.batteryPct! >= 0 ? '${tracker.batteryPct}%' : '—', good: (tracker.batteryPct ?? 100) > 20),
        _Metric(label: 'Sync', value: syncText),
      ]),
      if (tracker.uploadError != null && tracker.pending > 0) ...[
        const SizedBox(height: 10),
        Text(tracker.uploadError!, style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 12.5)),
      ],
      const SizedBox(height: 18),
      Row(children: [
        if (today.settings.pauseEnabled || paused)
          Expanded(
            child: FilledButton.icon(
              onPressed: busy
                  ? null
                  : paused
                      ? () => _run(context, () => context.read<DutyState>().resumeDuty(), 'Welcome back — duty resumed.')
                      : () => _pause(context),
              icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              label: Text(paused ? 'Resume' : 'Pause'),
              style: FilledButton.styleFrom(backgroundColor: paused ? AppColors.success : const Color(0xFF475569)),
            ),
          ),
        if (today.settings.pauseEnabled || paused) const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: busy ? null : () => _end(context),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('End duty'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
          ),
        ),
      ]),
    ]);
  }
}

class _NavyCard extends StatelessWidget {
  const _NavyCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.unit, this.good = true});
  final String label;
  final String value;
  final String? unit;
  final bool good;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: value, style: TextStyle(color: good ? Colors.white : const Color(0xFFFCA5A5), fontSize: 20, fontWeight: FontWeight.w800)),
              if (unit != null) TextSpan(text: ' $unit', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, this.unit, this.sub, this.muted = false});
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final bool muted;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: muted ? const Color(0xFFF1F5F9) : AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 18, color: muted ? AppColors.muted : AppColors.primary),
              ),
            ]),
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              TextSpan(text: value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: muted ? AppColors.muted : AppColors.navy)),
              if (unit != null) TextSpan(text: ' $unit', style: const TextStyle(fontSize: 14, color: AppColors.muted)),
            ])),
            if (sub != null) Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
      );
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(children: [
              Icon(icon, color: onTap == null ? AppColors.border : AppColors.primary),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: onTap == null ? AppColors.muted : AppColors.navy)),
            ]),
          ),
        ),
      );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.s});
  final DutySession s;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          child: ListTile(
            leading: Icon(s.isOpen ? Icons.directions_bike : Icons.flag_outlined, color: s.isOpen ? AppColors.success : AppColors.muted),
            title: Text('${fmtTime(s.startAt)} – ${s.isOpen ? 'now' : fmtTime(s.endAt)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${s.gpsKm.toStringAsFixed(1)} km GPS${s.gapKm > 0 ? ' + ${s.gapKm.toStringAsFixed(1)} km estimated' : ''}${s.workedSeconds != null ? ' · ${fmtDuration(s.workedSeconds!)}' : ''}'),
            trailing: StatusChip(s.status),
          ),
        ),
      );
}

class _BlockedCard extends StatelessWidget {
  const _BlockedCard({required this.error});
  final ApiException error;

  @override
  Widget build(BuildContext context) {
    final text = switch (error.code) {
      'NOT_FIELD_EMPLOYEE' => 'Duty tracking is for field staff. Your account is not marked as field staff — use the SkirlField web app instead.',
      'TRACKING_DISABLED' => 'GPS tracking is turned off for your account. Contact HR if you work in the field.',
      'EMPLOYEE_REQUIRED' => 'Your login is not linked to an employee record. Contact HR.',
      'MOBILE_APP_REQUIRED' => 'This phone is not your registered phone. Sign out and sign in again, or ask HR to approve this phone.',
      'PERMISSION_DENIED' => 'Your role does not include duty tracking. Contact HR.',
      _ => error.message,
    };
    return Banner2(text: text, icon: Icons.info_outline, color: AppColors.primary, soft: AppColors.primarySoft);
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});
  final ApiException error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Banner2(
        text: error.message,
        icon: Icons.cloud_off_outlined,
        color: AppColors.danger,
        soft: AppColors.dangerSoft,
        action: 'Retry',
        onAction: () => onRetry(),
      );
}
