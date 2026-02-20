import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

enum AvatarSize { small, medium, large, xlarge }

/// Минималистичный аватар
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final AvatarSize size;
  final bool showOnline;
  final bool isOnline;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = AvatarSize.medium,
    this.showOnline = false,
    this.isOnline = false,
  });

  double get _size {
    switch (size) {
      case AvatarSize.small: return 32;
      case AvatarSize.medium: return 44;
      case AvatarSize.large: return 64;
      case AvatarSize.xlarge: return 88;
    }
  }

  double get _fontSize {
    switch (size) {
      case AvatarSize.small: return 12;
      case AvatarSize.medium: return 16;
      case AvatarSize.large: return 22;
      case AvatarSize.xlarge: return 32;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceSecondary,
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildInitials(),
                    errorWidget: (_, __, ___) => _buildInitials(),
                  )
                : _buildInitials(),
          ),
        ),
        if (showOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: _size * 0.26,
              height: _size * 0.26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? AppColors.success : AppColors.textTertiary,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitials() {
    final initials = _getInitials();
    return Container(
      color: AppColors.primaryLight,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  String _getInitials() {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
