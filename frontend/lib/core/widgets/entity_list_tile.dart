import 'package:flutter/material.dart';
import 'package:flowers/app/theme/app_theme.dart';
import 'package:flowers/core/widgets/soft_card.dart';

class EntityListTile extends StatelessWidget {
  const EntityListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SoftCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: dense ? 10 : 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w800,
                    fontVariations: const [FontVariation('wght', 800)],
                    color: AppColors.ink,
                    fontSize: 17,
                  ),
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                      fontVariations: const [FontVariation('wght', 600)],
                      fontSize: 15,
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}
