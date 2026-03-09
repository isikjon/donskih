import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/rich_description_viewer.dart';
import 'video_player_helpers.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? description;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    this.description,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _isVerticalVideo = false;
  double _playbackSpeed = 1.0;

  double _dragOffset = 0;
  double _dragOpacity = 1.0;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      httpHeaders: const {'Connection': 'keep-alive'},
    )
      ..initialize().then((_) {
        if (!mounted) return;
        final size = _controller.value.size;
        _isVerticalVideo =
            VideoPlayerHelpers.isVerticalVideo(size.width, size.height);
        setState(() => _initialized = true);
        _controller.play();
        _hideControlsAfterDelay();
      }).catchError((e) {
        debugPrint('VIDEO ERROR: $e');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = e.toString();
          });
        }
      });
    _controller.addListener(_onVideoUpdate);
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  void _hideControlsAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
      _hideControlsAfterDelay();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls && _controller.value.isPlaying) {
      _hideControlsAfterDelay();
    }
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      if (_isVerticalVideo) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _seekRelative(Duration offset) {
    final pos = _controller.value.position + offset;
    _controller.seekTo(pos < Duration.zero ? Duration.zero : pos);
  }

  void _setSpeed(double speed) {
    _controller.setPlaybackSpeed(speed);
    setState(() => _playbackSpeed = speed);
  }

  void _showSpeedPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Скорость воспроизведения',
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ..._speeds.map((s) {
                  final selected = (_playbackSpeed - s).abs() < 0.01;
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${s}x',
                      style: TextStyle(
                        color: selected ? AppColors.primary : Colors.white,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 20)
                        : null,
                    onTap: () {
                      _setSpeed(s);
                      Navigator.pop(ctx);
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) => VideoPlayerHelpers.formatDuration(d);

  String get _speedLabel => VideoPlayerHelpers.speedLabel(_playbackSpeed);

  // -------------------------------------------------------------------------
  // Swipe-to-close
  // -------------------------------------------------------------------------

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (d.delta.dy < 0 && _dragOffset <= 0) return;
    setState(() {
      _dragOffset = VideoPlayerHelpers.clampDragOffset(_dragOffset, d.delta.dy);
      _dragOpacity = VideoPlayerHelpers.dragOpacity(_dragOffset);
    });
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (VideoPlayerHelpers.shouldDismiss(
        _dragOffset, d.velocity.pixelsPerSecond.dy)) {
      Navigator.pop(context);
    } else {
      setState(() {
        _dragOffset = 0;
        _dragOpacity = 1.0;
      });
    }
  }

  // -------------------------------------------------------------------------
  // Seek to seconds (timestamp tap)
  // -------------------------------------------------------------------------

  void _seekToSeconds(int seconds) {
    if (!_initialized || _hasError) return;
    final pos = Duration(seconds: seconds.clamp(0, _controller.value.duration.inSeconds));
    _controller.seekTo(pos);
    setState(() => _showControls = true);
    _hideControlsAfterDelay();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(_dragOpacity),
      body: GestureDetector(
        onVerticalDragUpdate: _isFullscreen ? null : _onVerticalDragUpdate,
        onVerticalDragEnd: _isFullscreen ? null : _onVerticalDragEnd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: Matrix4.translationValues(0, _dragOffset, 0),
          child: SafeArea(
            child: Column(
              children: [
                if (!_isFullscreen) _buildAppBar(),
                Expanded(child: _buildVideoArea()),
                if (!_isFullscreen) _buildBottomInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          Expanded(
            child: Text(
              widget.title,
              style: AppTypography.titleSmall.copyWith(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Speed button in app bar
          GestureDetector(
            onTap: _showSpeedPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _speedLabel,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text('Не удалось загрузить видео',
                  style: AppTypography.bodyMedium.copyWith(color: Colors.white54)),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_errorMessage,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Назад', style: AppTypography.buttonSmall.copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      onVerticalDragUpdate: _isFullscreen ? null : _onVerticalDragUpdate,
      onVerticalDragEnd: _isFullscreen ? null : _onVerticalDragEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          if (_showControls) _buildControlsOverlay(),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    final value = _controller.value;
    return Container(
      color: Colors.black38,
      child: Column(
        children: [
          if (_isFullscreen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      _toggleFullscreen();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  ),
                  Expanded(
                    child: Text(widget.title,
                        style: AppTypography.titleSmall.copyWith(color: Colors.white),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  GestureDetector(
                    onTap: _showSpeedPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_speedLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: Icons.replay_10_rounded,
                onTap: () => _seekRelative(const Duration(seconds: -10)),
              ),
              const SizedBox(width: 32),
              _ControlButton(
                icon: value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 56,
                onTap: _togglePlayPause,
              ),
              const SizedBox(width: 32),
              _ControlButton(
                icon: Icons.forward_10_rounded,
                onTap: () => _seekRelative(const Duration(seconds: 10)),
              ),
            ],
          ),
          const Spacer(),
          _buildProgressBar(value),
        ],
      ),
    );
  }

  Widget _buildProgressBar(VideoPlayerValue value) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value.duration.inMilliseconds > 0
                  ? value.position.inMilliseconds / value.duration.inMilliseconds
                  : 0,
              onChanged: (v) {
                _controller.seekTo(Duration(
                  milliseconds: (v * value.duration.inMilliseconds).toInt(),
                ));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(value.position),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                IconButton(
                  onPressed: _toggleFullscreen,
                  icon: Icon(
                    _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    color: Colors.white70, size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Text(_formatDuration(value.duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo() {
    final hasDescription = (widget.description ?? '').trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title,
              style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          if (hasDescription) ...[
            const SizedBox(height: 10),
            RichDescriptionViewer(
              subtitle: widget.description,
              textStyle: AppTypography.bodySmall.copyWith(color: Colors.white60),
              onTimestampTap: _seekToSeconds,
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + 16,
        height: size + 16,
        decoration: BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
