import 'package:flutter/material.dart';
import 'package:flowers/app/theme/app_theme.dart';

class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.step = 1,
    this.label,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double step;
  final String? label;

  String get _display {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            _RoundIconButton(
              icon: Icons.remove,
              onPressed: value - step >= min - 1e-9
                  ? () => onChanged(_clamp(value - step))
                  : null,
            ),
            Expanded(
              child: Text(
                _display,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            _RoundIconButton(
              icon: Icons.add,
              onPressed: () => onChanged(_clamp(value + step)),
            ),
          ],
        ),
      ],
    );
  }

  double _clamp(double v) => v < min ? min : v;
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.mist,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: onPressed == null ? AppColors.outline : AppColors.leafDark,
          ),
        ),
      ),
    );
  }
}
