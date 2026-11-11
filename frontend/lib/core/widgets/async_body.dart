import 'package:flutter/material.dart';

/// Shared loading / error / empty / content body for list-style screens.
class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.loading,
    this.error,
    this.isEmpty = false,
    this.emptyMessage = 'Нет данных',
    this.onRetry,
    required this.child,
  });

  final bool loading;
  final String? error;
  final bool isEmpty;
  final String emptyMessage;
  final VoidCallback? onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Повторить'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return child;
  }
}
