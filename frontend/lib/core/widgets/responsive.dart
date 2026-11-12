import 'package:flutter/material.dart';

abstract final class Breakpoints {
  static const phone = 600.0;
  static const tablet = 840.0;
  static const desktop = 1100.0;
}

bool isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < Breakpoints.phone;

bool isWideNav(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

/// Centers and clamps page content for laptop/desktop readability.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
