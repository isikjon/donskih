import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final double blur;
  final VoidCallback? onTap;
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blur = 20,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusLarge);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color ?? AppColors.glassFill,
              borderRadius: radius,
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
