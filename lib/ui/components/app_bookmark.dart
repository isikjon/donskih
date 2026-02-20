import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AnimatedBookmark extends StatefulWidget {
  final bool isBookmarked;
  final ValueChanged<bool> onToggle;
  final double size;

  const AnimatedBookmark({
    super.key,
    required this.isBookmarked,
    required this.onToggle,
    this.size = 24,
  });

  @override
  State<AnimatedBookmark> createState() => _AnimatedBookmarkState();
}

class _AnimatedBookmarkState extends State<AnimatedBookmark>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _particleController;
  late Animation<double> _bounceScale;
  late Animation<double> _particleRadius;
  late Animation<double> _particleOpacity;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.4), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeOut));

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _particleRadius = Tween<double>(begin: 0, end: 20).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeOut),
    );

    _particleOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    final newValue = !widget.isBookmarked;
    if (newValue) {
      _bounceController.forward(from: 0);
      _particleController.forward(from: 0);
    } else {
      _bounceController.forward(from: 0);
    }
    widget.onToggle(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size + 16,
        height: widget.size + 16,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isBookmarked)
              AnimatedBuilder(
                animation: _particleController,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.size + 32, widget.size + 32),
                    painter: _ParticlePainter(
                      radius: _particleRadius.value,
                      opacity: _particleOpacity.value,
                      color: AppColors.primary,
                    ),
                  );
                },
              ),
            AnimatedBuilder(
              animation: _bounceController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _bounceController.isAnimating ? _bounceScale.value : 1.0,
                  child: child,
                );
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  widget.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  key: ValueKey(widget.isBookmarked),
                  color: widget.isBookmarked ? AppColors.primary : AppColors.textTertiary,
                  size: widget.size,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double radius;
  final double opacity;
  final Color color;

  _ParticlePainter({
    required this.radius,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withValues(alpha: opacity * 0.8)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 8; i++) {
      final angle = (i * pi / 4);
      final dx = center.dx + radius * cos(angle);
      final dy = center.dy + radius * sin(angle);
      final dotSize = 2.5 * (1 - radius / 20).clamp(0.3, 1.0);
      canvas.drawCircle(Offset(dx, dy), dotSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return radius != oldDelegate.radius || opacity != oldDelegate.opacity;
  }
}
