import 'package:flutter/material.dart';
import 'package:flowers/app/theme/app_theme.dart';
import 'package:flowers/core/widgets/empty_state_view.dart';

/// Shared loading / error / empty / content body for list-style screens.
class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.loading,
    this.error,
    this.isEmpty = false,
    this.emptyMessage = 'Нет данных',
    this.emptyIcon = Icons.local_florist_outlined,
    this.onRetry,
    required this.child,
  });

  final bool loading;
  final String? error;
  final bool isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;
  final VoidCallback? onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.leaf,
          ),
        ),
      );
    }
    if (error != null) {
      return EmptyStateView(
        message: error!,
        icon: Icons.error_outline,
        actionLabel: 'Повторить',
        onAction: onRetry,
      );
    }
    if (isEmpty) {
      return EmptyStateView(
        message: emptyMessage,
        icon: emptyIcon,
        actionLabel: onRetry != null ? 'Обновить' : null,
        onAction: onRetry,
      );
    }
    return child;
  }
}
