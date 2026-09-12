import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import 'startup_mascot.dart';

/// A one-shot handoff from the native splash to the already-mounted app.
class StartupReveal extends StatefulWidget {
  const StartupReveal({
    super.key,
    required this.ready,
    required this.onPrepared,
    required this.child,
  });

  final bool ready;
  final VoidCallback onPrepared;
  final Widget child;

  @override
  State<StartupReveal> createState() => _StartupRevealState();
}

class _StartupRevealState extends State<StartupReveal>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 750),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _finished = true);
        }
      });
  bool _preparing = false;
  bool _prepared = false;
  bool _started = false;
  bool _finished = false;
  bool _imageFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _finished = true;
      _prepared = true;
      _tryStart();
    } else if (!_preparing) {
      _preparing = true;
      _prepareArtwork();
    }
  }

  Future<void> _prepareArtwork() async {
    await precacheImage(
      const AssetImage(AppAssets.homeHero),
      context,
      onError: (error, stack) {
        _imageFailed = true;
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            context: ErrorDescription('preparing the splash artwork'),
          ),
        );
      },
    );
    if (!mounted) return;
    setState(() {
      _prepared = true;
      if (_imageFailed) _finished = true;
    });
    _tryStart();
  }

  @override
  void didUpdateWidget(StartupReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tryStart();
  }

  void _tryStart() {
    if (!widget.ready || !_prepared || _started) return;
    _started = true;
    widget.onPrepared();
    if (_finished) return;
    // Match the root gate's native-splash removal after two destination frames.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_finished) _controller.forward();
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_finished)
          Positioned.fill(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Opacity(
                  opacity:
                      1 -
                      const Interval(
                        0.8,
                        1,
                        curve: Curves.easeOut,
                      ).transform(_controller.value),
                  child: child,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.ready
                      ? () => _controller.forward(from: 0.9)
                      : null,
                  child: ColoredBox(
                    color: dark
                        ? const Color(0xFF1C1B1F)
                        : const Color(0xFFF5F4F0),
                    child: Stack(
                      children: [
                        Center(
                          child: RepaintBoundary(
                            child: SizedBox.square(
                              dimension: StartupMascot.size,
                              child: AnimatedBuilder(
                                animation: _controller,
                                builder: (context, child) =>
                                    StartupMascot(progress: _controller.value),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 40 + MediaQuery.viewPaddingOf(context).bottom,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Image.asset(
                              dark
                                  ? 'assets/splash_branding_dark.png'
                                  : 'assets/splash_branding.png',
                              width: 200,
                              height: 80,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
