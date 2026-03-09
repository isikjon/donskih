import 'package:test/test.dart';
import 'package:club_app/ui/screens/video/video_player_helpers.dart';

void main() {
  group('VideoPlayerHelpers.formatDuration', () {
    test('formats seconds only', () {
      expect(VideoPlayerHelpers.formatDuration(const Duration(seconds: 5)),
          '00:05');
    });

    test('formats minutes and seconds', () {
      expect(
          VideoPlayerHelpers.formatDuration(
              const Duration(minutes: 3, seconds: 42)),
          '03:42');
    });

    test('formats hours', () {
      expect(
          VideoPlayerHelpers.formatDuration(
              const Duration(hours: 1, minutes: 5, seconds: 9)),
          '1:05:09');
    });

    test('formats zero', () {
      expect(VideoPlayerHelpers.formatDuration(Duration.zero), '00:00');
    });

    test('formats 59:59 without hours prefix', () {
      expect(
          VideoPlayerHelpers.formatDuration(
              const Duration(minutes: 59, seconds: 59)),
          '59:59');
    });

    test('formats exactly 1 hour', () {
      expect(VideoPlayerHelpers.formatDuration(const Duration(hours: 1)),
          '1:00:00');
    });
  });

  group('VideoPlayerHelpers.speedLabel', () {
    test('returns "1x" for 1.0', () {
      expect(VideoPlayerHelpers.speedLabel(1.0), '1x');
    });

    test('returns "2x" for 2.0 (drops .0)', () {
      expect(VideoPlayerHelpers.speedLabel(2.0), '2x');
    });

    test('returns "1.5x" for 1.5', () {
      expect(VideoPlayerHelpers.speedLabel(1.5), '1.5x');
    });

    test('returns "0.75x" for 0.75', () {
      expect(VideoPlayerHelpers.speedLabel(0.75), '0.75x');
    });

    test('returns "0.5x" for 0.5', () {
      expect(VideoPlayerHelpers.speedLabel(0.5), '0.5x');
    });

    test('returns "1.25x" for 1.25', () {
      expect(VideoPlayerHelpers.speedLabel(1.25), '1.25x');
    });

    test('treats 0.999999 close to 1.0 as "1x"', () {
      expect(VideoPlayerHelpers.speedLabel(0.999), '1x');
    });
  });

  group('VideoPlayerHelpers.clampDragOffset', () {
    test('adds positive delta', () {
      expect(VideoPlayerHelpers.clampDragOffset(0, 50), 50.0);
    });

    test('clamps to 0 on negative result', () {
      expect(VideoPlayerHelpers.clampDragOffset(10, -20), 0.0);
    });

    test('clamps to maxDragOffset', () {
      expect(VideoPlayerHelpers.clampDragOffset(350, 100),
          VideoPlayerHelpers.maxDragOffset);
    });

    test('accumulates correctly', () {
      var offset = 0.0;
      offset = VideoPlayerHelpers.clampDragOffset(offset, 100);
      offset = VideoPlayerHelpers.clampDragOffset(offset, 50);
      expect(offset, 150.0);
    });

    test('exact zero stays zero for negative delta from zero', () {
      expect(VideoPlayerHelpers.clampDragOffset(0, -10), 0.0);
    });
  });

  group('VideoPlayerHelpers.dragOpacity', () {
    test('returns 1.0 at offset 0', () {
      expect(VideoPlayerHelpers.dragOpacity(0), 1.0);
    });

    test('returns 0.5 at offset 200 (half of 400)', () {
      expect(VideoPlayerHelpers.dragOpacity(200), 0.5);
    });

    test('clamps to 0.3 at max offset', () {
      expect(VideoPlayerHelpers.dragOpacity(400), closeTo(0.3, 0.01));
    });

    test('never goes below 0.3', () {
      expect(VideoPlayerHelpers.dragOpacity(500), 0.3);
    });

    test('decreases monotonically as offset grows', () {
      final at50 = VideoPlayerHelpers.dragOpacity(50);
      final at100 = VideoPlayerHelpers.dragOpacity(100);
      final at150 = VideoPlayerHelpers.dragOpacity(150);
      expect(at50, greaterThan(at100));
      expect(at100, greaterThan(at150));
      expect(at50 - at100, closeTo(at100 - at150, 0.01));
    });
  });

  group('VideoPlayerHelpers.shouldDismiss', () {
    test('dismisses when offset exceeds threshold', () {
      expect(VideoPlayerHelpers.shouldDismiss(160, 0), isTrue);
    });

    test('does not dismiss when offset below threshold and low velocity', () {
      expect(VideoPlayerHelpers.shouldDismiss(100, 200), isFalse);
    });

    test('dismisses on high velocity even with small offset', () {
      expect(VideoPlayerHelpers.shouldDismiss(50, 900), isTrue);
    });

    test('dismisses on exactly threshold', () {
      expect(
          VideoPlayerHelpers.shouldDismiss(
              VideoPlayerHelpers.dismissThreshold + 1, 0),
          isTrue);
    });

    test('does not dismiss at exact threshold value', () {
      expect(
          VideoPlayerHelpers.shouldDismiss(
              VideoPlayerHelpers.dismissThreshold, 0),
          isFalse);
    });

    test('dismisses at exact velocity threshold', () {
      expect(
          VideoPlayerHelpers.shouldDismiss(
              0, VideoPlayerHelpers.dismissVelocity + 1),
          isTrue);
    });
  });

  group('VideoPlayerHelpers.isVerticalVideo', () {
    test('portrait video (1080x1920)', () {
      expect(VideoPlayerHelpers.isVerticalVideo(1080, 1920), isTrue);
    });

    test('landscape video (1920x1080)', () {
      expect(VideoPlayerHelpers.isVerticalVideo(1920, 1080), isFalse);
    });

    test('square video is not vertical', () {
      expect(VideoPlayerHelpers.isVerticalVideo(1080, 1080), isFalse);
    });

    test('slightly taller than wide is vertical', () {
      expect(VideoPlayerHelpers.isVerticalVideo(100, 101), isTrue);
    });
  });

  group('Swipe-to-close full scenario', () {
    test('simulates a full swipe-to-dismiss gesture', () {
      var offset = 0.0;
      var opacity = 1.0;

      for (var i = 0; i < 20; i++) {
        offset = VideoPlayerHelpers.clampDragOffset(offset, 10);
        opacity = VideoPlayerHelpers.dragOpacity(offset);
      }

      expect(offset, 200.0);
      expect(opacity, closeTo(0.5, 0.01));
      expect(VideoPlayerHelpers.shouldDismiss(offset, 0), isTrue);
    });

    test('simulates a small drag that snaps back', () {
      var offset = 0.0;

      for (var i = 0; i < 5; i++) {
        offset = VideoPlayerHelpers.clampDragOffset(offset, 10);
      }

      expect(offset, 50.0);
      expect(VideoPlayerHelpers.shouldDismiss(offset, 100), isFalse);

      offset = 0;
      expect(VideoPlayerHelpers.dragOpacity(offset), 1.0);
    });

    test('fast flick dismisses even with small offset', () {
      var offset = 0.0;
      offset = VideoPlayerHelpers.clampDragOffset(offset, 30);
      expect(offset, 30.0);
      expect(VideoPlayerHelpers.shouldDismiss(offset, 1200), isTrue);
    });
  });
}
