import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Mobile-safe dialog body: constrained width + vertical scroll.
class AppDialogScrollBody extends StatelessWidget {
  const AppDialogScrollBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = math.min(width - 48, 420.0);
    return SizedBox(
      width: maxWidth,
      child: SingleChildScrollView(child: child),
    );
  }
}
