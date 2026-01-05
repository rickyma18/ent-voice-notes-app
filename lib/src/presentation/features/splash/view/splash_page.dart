import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/logger/log.dart';
import '../../../core/application_state/startup_coordinator/startup_coordinator_provider.dart';

/// Splash page that displays a branding video during app startup.
///
/// ## Architecture Notes
///
/// This page is **in control** of the initial navigation flow:
/// - It notifies [StartupCoordinator] when the video completes
/// - The router will NOT redirect until this notification occurs
/// - This ensures the branding video always plays to completion
///
/// ## Error Handling
///
/// If the video fails to load or play:
/// - The coordinator is notified of the error
/// - A fallback static logo is displayed
/// - Navigation proceeds after minimum duration
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _hasNotifiedCompletion = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      Log.info('[SplashPage] Initializing video controller');

      _controller = VideoPlayerController.asset(
        'assets/branding/animation/docsoft_animation.mp4',
      );

      await _controller!.initialize();
      await _controller!.setVolume(0.0);
      await _controller!.setLooping(false);

      // Listen for video completion
      _controller!.addListener(_onVideoStateChanged);

      if (!mounted) return;

      setState(() => _initialized = true);

      Log.info(
        '[SplashPage] Video initialized, duration: ${_controller!.value.duration}',
      );

      await _controller!.play();
      Log.info('[SplashPage] Video playback started');
    } catch (error, stackTrace) {
      Log.error('[SplashPage] Video initialization failed: $error');
      Log.error(stackTrace.toString());

      if (!mounted) return;

      setState(() => _hasError = true);

      // Notify coordinator of the error
      ref.read(startupCoordinatorProvider.notifier).onSplashVideoError(error);
    }
  }

  void _onVideoStateChanged() {
    if (!mounted) return;

    final controller = _controller;
    if (controller == null) return;

    // Update UI
    setState(() {});

    // Check if video has completed
    final position = controller.value.position;
    final duration = controller.value.duration;

    // Video is complete when position >= duration (with small tolerance)
    // and video is no longer playing
    final isComplete = duration.inMilliseconds > 0 &&
        position.inMilliseconds >= (duration.inMilliseconds - 100) &&
        !controller.value.isPlaying;

    if (isComplete && !_hasNotifiedCompletion) {
      _notifyVideoCompleted();
    }
  }

  void _notifyVideoCompleted() {
    if (_hasNotifiedCompletion) return;
    _hasNotifiedCompletion = true;

    Log.info('[SplashPage] Video completed, notifying coordinator');
    ref.read(startupCoordinatorProvider.notifier).onSplashVideoCompleted();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoStateChanged);
    _controller?.dispose();
    Log.info('[SplashPage] Disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    // Error state: show static fallback
    if (_hasError) {
      return _buildFallbackLogo();
    }

    // Loading state: show nothing (or could show static logo)
    if (!_initialized || _controller == null) {
      return const SizedBox.shrink();
    }

    // Video playing state
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }

  Widget _buildFallbackLogo() {
    // Fallback when video fails - show static branding
    return Image.asset(
      'assets/branding/logo.png',
      width: 200,
      height: 200,
      errorBuilder: (context, error, stackTrace) {
        // Even the fallback image failed, show app name
        return const Text(
          'Docsoft',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E88E5),
          ),
        );
      },
    );
  }
}
