import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../ui/theme/colors.dart';
import '../../../../core/logger/log.dart';
import '../../../core/application_state/startup_coordinator/startup_coordinator_provider.dart';

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

      _controller!.addListener(_onVideoStateChanged);

      if (!mounted) return;

      setState(() {
        _initialized = true;
        _hasError = false;
      });

      Log.info(
        '[SplashPage] Video initialized, duration: ${_controller!.value.duration}, '
        'size: ${_controller!.value.size}, aspectRatio: ${_controller!.value.aspectRatio}',
      );

      await _controller!.play();
      Log.info('[SplashPage] Video playback started');
    } catch (error, stackTrace) {
      Log.error('[SplashPage] Video initialization failed: $error');
      Log.error(stackTrace.toString());

      if (!mounted) return;

      setState(() => _hasError = true);
      ref.read(startupCoordinatorProvider.notifier).onSplashVideoError(error);
    }
  }

  void _onVideoStateChanged() {
    if (!mounted) return;

    final controller = _controller;
    if (controller == null) return;

    final value = controller.value;

    final durationMs = value.duration.inMilliseconds;
    if (durationMs > 0) {
      final positionMs = value.position.inMilliseconds;

      final isComplete =
          positionMs >= (durationMs - 100) && value.isPlaying == false;

      if (isComplete && !_hasNotifiedCompletion) {
        _notifyVideoCompleted();
      }
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
      backgroundColor: DocsoftColors.backgroundAlt,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Center(child: _buildFallbackLogo());
    }

    if (!_initialized || _controller == null) {
      return const SizedBox.shrink();
    }

    final controller = _controller!;
    final videoSize = controller.value.size;

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              child: SizedBox(
                width: videoSize.width,
                height: videoSize.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackLogo() {
    return Image.asset(
      'assets/branding/logo.png',
      width: 200,
      height: 200,
      errorBuilder: (context, error, stackTrace) {
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
