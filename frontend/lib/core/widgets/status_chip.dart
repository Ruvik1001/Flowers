import 'package:flutter/material.dart';
import 'package:flowers/app/theme/app_theme.dart';

enum StatusTone { neutral, success, warning, danger, accent }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
  });

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusTone.success => (
          AppColors.success.withValues(alpha: 0.14),
          AppColors.success,
        ),
      StatusTone.warning => (
          AppColors.warning.withValues(alpha: 0.16),
          AppColors.warning,
        ),
      StatusTone.danger => (
          const Color(0xFFB3261E).withValues(alpha: 0.12),
          const Color(0xFFB3261E),
        ),
      StatusTone.accent => (
          AppColors.blush.withValues(alpha: 0.18),
          AppColors.leafDark,
        ),
      StatusTone.neutral => (
          AppColors.mist,
          AppColors.muted,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
