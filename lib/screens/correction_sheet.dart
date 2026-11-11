import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<bool?> showCorrectionSheet(BuildContext context, AttendanceDay day) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CorrectionSheet(day: day),
    );

class CorrectionSheet extends StatefulWidget {
  const CorrectionSheet({super.key, required this.day});
  final AttendanceDay day;

  @override
  State<CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<CorrectionSheet> {
  late final List<DutySession> _sessions = widget.day.sessions.where((s) => !s.isOpen).toList();
  late String _type = _sessions.isEmpty ? 'MARK_STATUS' : 'FIX_END';
  DutySession? _session;
  TimeOfDay? _start;
  TimeOfDay? _end;
  String _status = 'PRESENT';
  final _reason = TextEditingController();
  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    if (_sessions.isNotEmpty) _pickSession(_sessions.last);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _pickSession(DutySession s) {
    _session = s;
    final a = s.startAt, b = s.endAt;
    _start = a == null ? null : TimeOfDay(hour: a.hour, minute: a.minute);
    _end = b == null ? null : TimeOfDay(hour: b.hour, minute: b.minute);
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(context: context, initialTime: (start ? _start : _end) ?? TimeOfDay.now());
    if (t != null) setState(() => start ? _start = t : _end = t);
  }

  Future<void> _submit() async {
    if (_reason.text.trim().length < 5) {
      setState(() => _errors = {'reason': 'Write a short reason (at least 5 characters).'});
      return;
    }
    setState(() {
      _busy = true;
      _errors = {};
    });
    try {
      await Api.instance.post('/attendance/corrections', {
        'business_date': widget.day.date,
        'correction_type': _type,
        if (_type != 'MARK_STATUS') 'session_id': _session?.id,
        if ((_type == 'FIX_START' || _type == 'FIX_BOTH') && _start != null) 'requested_start': hhmm(_start!.hour, _start!.minute),
        if ((_type == 'FIX_END' || _type == 'FIX_BOTH') && _end != null) 'requested_end': hhmm(_end!.hour, _end!.minute),
        if (_type == 'MARK_STATUS') 'requested_status': _status,
        'reason': _reason.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Sent to HR for approval.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'VALIDATION_FAILED') {
        setState(() => _errors = e.fields);
        if (e.fields.keys.any((k) => !const {'reason'}.contains(k))) showError(context, e);
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _timeField(String label, TimeOfDay? t, bool start, String errKey) => Expanded(
        child: InkWell(
          onTap: () => _pickTime(start),
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, errorText: _errors[errKey], suffixIcon: const Icon(Icons.schedule)),
            child: Text(t == null ? 'Choose' : t.format(context)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Correct ${fmtDate(widget.day.day)}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 4),
          const Text('HR checks your request. Your GPS distance is never changed.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in const [('FIX_START', 'Start time'), ('FIX_END', 'End time'), ('FIX_BOTH', 'Both times'), ('MARK_STATUS', 'Day status')])
              ChoiceChip(
                label: Text(t.$2),
                selected: _type == t.$1,
                onSelected: (t.$1 != 'MARK_STATUS' && _sessions.isEmpty) ? null : (_) => setState(() => _type = t.$1),
              ),
          ]),
          const SizedBox(height: 16),
          if (_type != 'MARK_STATUS') ...[
            if (_sessions.length > 1) ...[
              DropdownButtonFormField<int>(
                initialValue: _session?.id,
                decoration: InputDecoration(labelText: 'Which duty', errorText: _errors['session_id']),
                items: [for (final s in _sessions) DropdownMenuItem(value: s.id, child: Text('${fmtTime(s.startAt)} – ${fmtTime(s.endAt)}'))],
                onChanged: (id) => setState(() => _pickSession(_sessions.firstWhere((s) => s.id == id))),
              ),
              const SizedBox(height: 14),
            ] else if (_errors['session_id'] != null) ...[
              Text(_errors['session_id']!, style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 8),
            ],
            Row(children: [
              if (_type != 'FIX_END') _timeField('Correct start', _start, true, 'requested_start'),
              if (_type == 'FIX_BOTH') const SizedBox(width: 12),
              if (_type != 'FIX_START') _timeField('Correct end', _end, false, 'requested_end'),
            ]),
          ] else
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: InputDecoration(labelText: 'Mark the day as', errorText: _errors['requested_status']),
              items: const [
                DropdownMenuItem(value: 'PRESENT', child: Text('Present')),
                DropdownMenuItem(value: 'HALF_DAY', child: Text('Half day')),
                DropdownMenuItem(value: 'LEAVE', child: Text('Leave')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'PRESENT'),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _reason,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(labelText: 'Reason', hintText: 'e.g. Phone battery died at the last customer, ended at 6:40 PM', errorText: _errors['reason']),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Send to HR'),
          ),
        ]),
      ),
    );
  }
}
