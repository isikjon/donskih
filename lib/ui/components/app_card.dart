import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class ListCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool showArrow;

  const ListCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(
                    icon,
                    color: iconColor ?? AppColors.textSecondary,
                    size: 24,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (showArrow)
                const Icon(Icons.chevron_right_outlined, color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
