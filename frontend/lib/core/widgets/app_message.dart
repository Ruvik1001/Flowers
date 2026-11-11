import 'package:flutter/material.dart';

class AppMessage {
  AppMessage._();

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, background: Colors.green.shade700);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, background: Theme.of(context).colorScheme.error);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message);
  }

  static void _show(
    BuildContext context,
    String message, {
    Color? background,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
