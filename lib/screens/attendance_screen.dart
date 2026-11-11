import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'correction_sheet.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => AttendanceScreenState();
}

class AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<AttendanceDay>? _days;
  List<Correction> _requests = [];
  ApiException? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      final key = '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
      final j = await Api.instance.get('/attendance/me', query: {'month': key}) as Map;
      final days = (j['days'] as List).map((e) => AttendanceDay(Map<String, dynamic>.from(e as Map))).toList();
      List<Correction> reqs = _requests;
      try {
        final p = await Api.instance.getPage('/attendance/corrections', query: {'per_page': 10});
        reqs = p.items.map(Correction.new).toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _days = days;
        _requests = reqs;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shift(int months) {
    final next = DateTime(_month.year, _month.month + months);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _month = next;
      _days = null;
    });
    reload();
  }

  Future<void> _openDay(AttendanceDay d) async {
    final asked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DaySheet(day: d),
    );
    if (asked == true) reload();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = (_days ?? []).where((d) => !d.day.isAfter(today)).toList().reversed.toList();
    int count(bool Function(AttendanceDay) f) => days.where(f).length;
    final km = days.fold<double>(0, (t, d) => t + d.km);
    final pending = _requests.where((r) => r.status == 'PENDING').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My attendance')),
      body: RefreshIndicator(
        onRefresh: reload,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
          Row(children: [
            IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left), tooltip: 'Previous month'),
            Expanded(child: Text(fmtMonth(_month.year, _month.month), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            IconButton(
              onPressed: _month.year == now.year && _month.month == now.month ? null : () => _shift(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
            ),
          ]),
          const SizedBox(height: 8),
          if (_error != null)
            Banner2(text: _error!.message, color: AppColors.danger, soft: AppColors.dangerSoft, action: 'Retry', onAction: reload)
          else if (_days == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else ...[
            Row(children: [
              _Count('Present', count((d) => d.status == 'PRESENT' || d.status == 'ON_DUTY'), AppColors.success),
              _Count('Half day', count((d) => d.status == 'HALF_DAY'), AppColors.warning),
              _Count('Absent', count((d) => d.status == 'ABSENT'), AppColors.danger),
              _Count('Late', count((d) => d.lateMinutes > 0), AppColors.warning),
            ]),
            const SizedBox(height: 10),
            Text('${km.toStringAsFixed(1)} km GPS this month', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            if (pending.isNotEmpty) ...[
              const SectionTitle('Waiting for approval'),
              for (final r in pending) _RequestTile(r),
            ],
            const SectionTitle('Days', trailing: Text('Tap a day to fix it', style: TextStyle(color: AppColors.muted, fontSize: 12.5))),
            if (days.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No days yet this month.', textAlign: TextAlign.center)),
            for (final d in days) _DayTile(d: d, onTap: () => _openDay(d)),
            if (_requests.any((r) => r.status != 'PENDING')) ...[
              const SectionTitle('Recent decisions'),
              for (final r in _requests.where((r) => r.status != 'PENDING')) _RequestTile(r),
            ],
          ],
          if (_loading && _days != null) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
        ]),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.n, this.color);
  final String label;
  final int n;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              Text('$n', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
        ),
      );
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.d, required this.onTap});
  final AttendanceDay d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final worked = d.workedSeconds > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              SizedBox(
                width: 46,
                child: Column(children: [
                  Text('${d.day.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
                  Text(fmtDayShort(d.day).split(',').first, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(worked ? '${fmtTime(d.firstIn)} – ${d.lastOut == null ? 'now' : fmtTime(d.lastOut)}' : '—', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (worked) fmtDuration(d.workedSeconds),
                      if (d.km > 0) fmtKm(d.km),
                      if (d.lateMinutes > 0) '${d.lateMinutes} min late',
                      if (d.isCorrected) 'corrected',
                    ].join(' · '),
                    style: TextStyle(fontSize: 13, color: d.lateMinutes > 0 ? AppColors.warning : AppColors.muted),
                  ),
                ]),
              ),
              StatusChip(d.status),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile(this.r);
  final Correction r;

  @override
  Widget build(BuildContext context) {
    final what = switch (r.type) {
      'FIX_START' => 'Start time → ${fmtTime(r.requestedStart)}',
      'FIX_END' => 'End time → ${fmtTime(r.requestedEnd)}',
      'FIX_BOTH' => '${fmtTime(r.requestedStart)} – ${fmtTime(r.requestedEnd)}',
      _ => 'Mark as ${(r.requestedStatus ?? '').replaceAll('_', ' ').toLowerCase()}',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          title: Text('${fmtDate(DateTime.parse(r.businessDate))} · $what', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
          subtitle: Text(r.reviewNote != null ? '${r.reviewedBy ?? 'HR'}: ${r.reviewNote}' : r.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: StatusChip(r.status),
        ),
      ),
    );
  }
}

/// One day: its duties and the "ask for a correction" entry point.
class DaySheet extends StatelessWidget {
  const DaySheet({super.key, required this.day});
  final AttendanceDay day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final age = DateTime(now.year, now.month, now.day).difference(day.day).inDays;
    final canAsk = age >= 0 && age <= 31 && day.status != 'ON_DUTY';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(fmtDate(day.day), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.navy))),
          StatusChip(day.status),
        ]),
        const SizedBox(height: 14),
        if (day.sessions.isEmpty)
          const Text('No duty recorded on this day.', style: TextStyle(color: AppColors.muted))
        else
          for (final s in day.sessions)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${fmtTime(s.startAt)} – ${s.isOpen ? 'now' : fmtTime(s.endAt)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(fmtKm(s.gpsKm)),
                trailing: StatusChip(s.status),
              ),
            ),
        const SizedBox(height: 12),
        if (day.status == 'ON_DUTY')
          const Text('End duty first to ask for a correction for today.', style: TextStyle(color: AppColors.muted))
        else if (canAsk)
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Ask HR to correct this day'),
            onPressed: () async {
              final ok = await showCorrectionSheet(context, day);
              if (ok == true && context.mounted) Navigator.pop(context, true);
            },
          )
        else
          const Text('Corrections are possible for the last 31 days only.', style: TextStyle(color: AppColors.muted)),
      ]),
    );
  }
}
