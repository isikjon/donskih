class VideoPlayerHelpers {
  VideoPlayerHelpers._();

  static const double maxDragOffset = 400.0;
  static const double dismissThreshold = 150.0;
  static const double dismissVelocity = 800.0;

  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static String speedLabel(double speed) {
    if ((speed - 1.0).abs() < 0.01) return '1x';
    final s = speed.toString();
    return s.endsWith('.0') ? '${speed.toInt()}x' : '${s}x';
  }

  static double clampDragOffset(double current, double deltaY) {
    return (current + deltaY).clamp(0.0, maxDragOffset);
  }

  static double dragOpacity(double offset) {
    return (1.0 - offset / maxDragOffset).clamp(0.3, 1.0);
  }

  static bool shouldDismiss(double offset, double velocityY) {
    return offset > dismissThreshold || velocityY > dismissVelocity;
  }

  static bool isVerticalVideo(double width, double height) {
    return height > width;
  }
}
