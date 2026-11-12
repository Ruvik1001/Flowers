import 'package:flutter/material.dart';
import 'package:flowers/app/theme/app_theme.dart';

class EmptyStateView extends StatefulWidget {
  const EmptyStateView({
    super.key,
    required this.message,
    this.icon = Icons.local_florist_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<EmptyStateView> createState() => _EmptyStateViewState();
}

class _EmptyStateViewState extends State<EmptyStateView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.leaf.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 34, color: AppColors.leaf),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
                if (widget.onAction != null) ...[
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: widget.onAction,
                    child: Text(widget.actionLabel ?? 'Повторить'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
