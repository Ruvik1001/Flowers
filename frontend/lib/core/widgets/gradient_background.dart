import 'package:flutter/material.dart';
import 'package:flowers/app/theme/app_theme.dart';

/// Warm paper atmosphere with a soft botanical wash.
class GradientBackground extends StatelessWidget {
  const GradientBackground({
    super.key,
    required this.child,
    this.intense = false,
  });

  final Widget child;
  final bool intense;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: intense
              ? const [
                  Color(0xFFF8F3EB),
                  AppColors.paper,
                  Color(0xFFE4EDE7),
                  Color(0xFFE9D8D6),
                ]
              : const [
                  Color(0xFFF8F4EC),
                  AppColors.paper,
                  Color(0xFFEDF1EB),
                ],
          stops: intense ? const [0.0, 0.35, 0.75, 1.0] : const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.leaf.withValues(alpha: intense ? 0.08 : 0.05),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blush.withValues(alpha: intense ? 0.10 : 0.06),
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
