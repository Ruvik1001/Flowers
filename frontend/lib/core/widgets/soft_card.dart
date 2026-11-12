import 'package:flutter/material.dart';
import 'package:flowers/app/theme/app_theme.dart';

/// Soft elevated surface for interactive rows and form groups.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.md);
    final surface = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.92),
        borderRadius: radius,
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.55)),
        boxShadow: softShadow(opacity: 0.06),
      ),
      child: child,
    );

    final ink = onTap == null
        ? surface
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              splashColor: AppColors.leaf.withValues(alpha: 0.08),
              highlightColor: AppColors.leaf.withValues(alpha: 0.04),
              child: surface,
            ),
          );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ink,
    );
  }
}
