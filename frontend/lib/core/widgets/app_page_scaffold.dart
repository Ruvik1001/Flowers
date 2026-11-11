import 'package:flutter/material.dart';
import 'package:flowers/core/widgets/gradient_background.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    this.title,
    this.actions,
    this.bottom,
    this.floatingActionButton,
    this.body,
    this.padding,
    this.extendBodyBehindAppBar = false,
  });

  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;
  final Widget? body;
  final EdgeInsetsGeometry? padding;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        appBar: title == null && actions == null && bottom == null
            ? null
            : AppBar(
                title: title,
                actions: actions,
                bottom: bottom,
              ),
        floatingActionButton: floatingActionButton == null
            ? null
            : ScaleTransitionFab(child: floatingActionButton!),
        body: padding == null
            ? body
            : Padding(padding: padding!, child: body),
      ),
    );
  }
}

class ScaleTransitionFab extends StatefulWidget {
  const ScaleTransitionFab({super.key, required this.child});

  final Widget child;

  @override
  State<ScaleTransitionFab> createState() => _ScaleTransitionFabState();
}

class _ScaleTransitionFabState extends State<ScaleTransitionFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
