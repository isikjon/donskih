import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String? avatarUrl;
  final bool showHomeDot;
  final bool showChatDot;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.avatarUrl,
    this.showHomeDot = false,
    this.showChatDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      margin: EdgeInsets.only(
        left: mq.size.width * 0.15,
        right: mq.size.width * 0.15,
        bottom: mq.padding.bottom + 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / 4;
                final indicatorLeft = itemWidth * currentIndex;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      left: indicatorLeft,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: const _ActiveIndicator(),
                    ),
                    Row(
                      children: [
                    _NavItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          isActive: currentIndex == 0,
                          onTap: () => onTap(0),
                          showDot: showHomeDot,
                        ),
                    _NavItem(
                          icon: Icons.auto_stories_outlined,
                          activeIcon: Icons.auto_stories_rounded,
                          isActive: currentIndex == 1,
                          onTap: () => onTap(1),
                        ),
                    _NavItem(
                          icon: Icons.chat_bubble_outline_rounded,
                          activeIcon: Icons.chat_bubble_rounded,
                          isActive: currentIndex == 2,
                          onTap: () => onTap(2),
                          showDot: showChatDot,
                        ),
                        _ProfileNavItem(
                          isActive: currentIndex == 3,
                          onTap: () => onTap(3),
                          imageUrl: avatarUrl,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveIndicator extends StatelessWidget {
  const _ActiveIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.primaryLight,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 0.5),
        boxShadow: const [
          BoxShadow(color: Color(0x14F26061), blurRadius: 12),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;
  final bool showDot;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _BounceTap(
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    isActive ? activeIcon : icon,
                    key: ValueKey(isActive),
                    color: isActive ? AppColors.primary : AppColors.textTertiary,
                    size: 26,
                  ),
                ),
                if (showDot)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  final String? imageUrl;

  const _ProfileNavItem({
    required this.isActive,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _BounceTap(
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.surfaceSecondary),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surfaceSecondary,
                          child: const Icon(Icons.person, size: 14, color: AppColors.textTertiary),
                        ),
                      )
                    : Container(
                        color: AppColors.surfaceSecondary,
                        child: const Icon(Icons.person, size: 14, color: AppColors.textTertiary),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BounceTap extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _BounceTap({required this.onTap, required this.child});

  @override
  State<_BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<_BounceTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.forward(from: 0);
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}
