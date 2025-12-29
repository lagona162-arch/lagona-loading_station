import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onPressed,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        if (actionLabel != null && onPressed != null)
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

