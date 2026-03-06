import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../core/theme/app_typography.dart';

/// Telegram-style fullscreen media viewer for chat images.
/// Supports: Hero animation, pinch/double-tap zoom, gallery swipe, tap/back to close, caption.
class MediaViewerScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String? caption;
  /// Hero tag for the image at [initialIndex]. If null, no Hero animation.
  final String? heroTag;

  MediaViewerScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.caption,
    this.heroTag,
  }) : assert(imageUrls.isNotEmpty),
       assert(initialIndex >= 0 && initialIndex < imageUrls.length);

  static const String routeName = '/media_viewer';

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  bool _isLocalUrl(String url) => url.startsWith('file://');

  ImageProvider _imageProvider(String url) {
    if (_isLocalUrl(url)) {
      final path = url.replaceFirst('file://', '');
      return FileImage(File(path));
    }
    return CachedNetworkImageProvider(url);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Gallery: pinch zoom, double-tap zoom, swipe between images
            PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: _imageProvider(widget.imageUrls[index]),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2.5,
                  initialScale: PhotoViewComputedScale.contained,
                  heroAttributes: (widget.heroTag != null && index == widget.initialIndex)
                      ? PhotoViewHeroAttributes(tag: widget.heroTag!)
                      : null,
                );
              },
              itemCount: widget.imageUrls.length,
              loadingBuilder: (_, __) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              pageController: _pageController,
              onPageChanged: (int index) => setState(() => _currentIndex = index),
            ),

            // Close button (tap to close)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: _close,
                  ),
                ),
              ),
            ),

            // Caption at bottom (Telegram-style)
            if (widget.caption != null && widget.caption!.isNotEmpty) _buildCaption(),
          ],
        ),
      ),
    );
  }

  static const double _captionMaxHeight = 200;

  Widget _buildCaption() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: false,
        child: GestureDetector(
          onTap: () {}, // absorb tap so it doesn't close
          child: Container(
            constraints: const BoxConstraints(maxHeight: _captionMaxHeight),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black,
                ],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Text(
                  widget.caption!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
