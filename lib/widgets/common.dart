import 'package:flutter/material.dart';

import '../core/api.dart';
import '../theme.dart';

void showSnack(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.danger : AppColors.navy,
      behavior: SnackBarBehavior.floating,
    ));
}

String errorText(Object e) => e is ApiException ? e.friendly : 'Something went wrong. Try again.';

void showError(BuildContext context, Object e) => showSnack(context, errorText(e), error: true);

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String status;
  final String? label;

  static const _map = <String, (Color, Color, String)>{
    'ON_DUTY': (AppColors.success, AppColors.successSoft, 'On duty'),
    'ACTIVE': (AppColors.success, AppColors.successSoft, 'On duty'),
    'PAUSED': (AppColors.purple, AppColors.purpleSoft, 'Paused'),
    'PRESENT': (AppColors.success, AppColors.successSoft, 'Present'),
    'HALF_DAY': (AppColors.warning, AppColors.warningSoft, 'Half day'),
    'ABSENT': (AppColors.danger, AppColors.dangerSoft, 'Absent'),
    'NOT_STARTED': (AppColors.muted, Color(0xFFF1F5F9), 'Not started'),
    'HOLIDAY': (AppColors.purple, AppColors.purpleSoft, 'Holiday'),
    'WEEK_OFF': (AppColors.muted, Color(0xFFF1F5F9), 'Week off'),
    'LEAVE': (AppColors.purple, AppColors.purpleSoft, 'Leave'),
    'UPCOMING': (AppColors.muted, Color(0xFFF1F5F9), '—'),
    'OFF_DUTY': (AppColors.muted, Color(0xFFF1F5F9), 'Off duty'),
    'ENDED': (AppColors.muted, Color(0xFFF1F5F9), 'Ended'),
    'AUTO_CLOSED': (AppColors.warning, AppColors.warningSoft, 'Auto-closed'),
    'CORRECTED': (AppColors.purple, AppColors.purpleSoft, 'Corrected'),
    'PENDING': (AppColors.warning, AppColors.warningSoft, 'Pending'),
    'APPROVED': (AppColors.success, AppColors.successSoft, 'Approved'),
    'REJECTED': (AppColors.danger, AppColors.dangerSoft, 'Rejected'),
  };

  @override
  Widget build(BuildContext context) {
    final m = _map[status] ?? (AppColors.muted, const Color(0xFFF1F5F9), status.replaceAll('_', ' '));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: m.$2, borderRadius: BorderRadius.circular(20)),
      child: Text(label ?? m.$3, style: TextStyle(color: m.$1, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navy))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Coloured strip with an icon, text and an optional action.
class Banner2 extends StatelessWidget {
  const Banner2({super.key, required this.text, this.icon = Icons.info_outline, this.color = AppColors.warning, this.soft = AppColors.warningSoft, this.action, this.onAction});
  final String text;
  final IconData icon;
  final Color color;
  final Color soft;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: AppColors.body, fontSize: 13.5, height: 1.3))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
        ]),
      );
}

class Avatar extends StatelessWidget {
  const Avatar(this.text, {super.key, this.size = 46, this.dot});
  final String text;
  final double size;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Text(text, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.36)),
        ),
        if (dot != null)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(width: 14, height: 14, decoration: BoxDecoration(color: dot, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5))),
          ),
      ]);
}
