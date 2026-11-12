import 'package:flutter/material.dart';
import 'package:flowers/core/widgets/gradient_background.dart';
import 'package:flowers/core/widgets/responsive.dart';

/// Full-screen editor: title + primary action in AppBar.
/// Content is width-clamped on laptop/desktop.
class EditorScaffold extends StatelessWidget {
  const EditorScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel = 'Сохранить',
    this.onAction,
    this.actionLoading = false,
    this.bottomBar,
  });

  final String title;
  final Widget body;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool actionLoading;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (onAction != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: actionLoading ? null : onAction,
                  child: actionLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(actionLabel),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: ContentWidth(
            maxWidth: 640,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [body],
            ),
          ),
        ),
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}
