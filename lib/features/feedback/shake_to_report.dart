import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/services/app_haptics.dart';
import '../../core/services/shake_detector.dart';
import 'feedback_service.dart';

/// Shake the phone to report a problem, as in Meta's apps. Listens to the
/// accelerometer only while the app is in front and the setting is on, and
/// hands over a picture of the screen as it was.
class ShakeToReport extends ConsumerStatefulWidget {
  const ShakeToReport({
    super.key,
    required this.child,
    required this.canReport,
    required this.onShake,
  });

  final Widget child;

  /// False where a report must not open: the Vault (private, never
  /// pictured), the share sheet, the report screen itself, before sign-in.
  final bool Function() canReport;

  final void Function(Uint8List? screenshot) onShake;

  @override
  ConsumerState<ShakeToReport> createState() => _ShakeToReportState();
}

class _ShakeToReportState extends ConsumerState<ShakeToReport>
    with WidgetsBindingObserver {
  final _boundary = GlobalKey();
  final _detector = ShakeDetector();
  StreamSubscription<UserAccelerometerEvent>? _sensor;
  var _resumed = true;
  var _reporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    ref.listenManual<bool>(
      shakeToReportProvider,
      (_, enabled) => _sync(enabled),
      fireImmediately: true,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _sync(ref.read(shakeToReportProvider));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sensor?.cancel();
    super.dispose();
  }

  /// Sensor on only while it can matter: saves battery, and nothing is
  /// read in the background.
  void _sync(bool enabled) {
    final listen =
        enabled && _resumed && defaultTargetPlatform == TargetPlatform.android;
    if (listen && _sensor == null) {
      _detector.reset();
      _sensor =
          userAccelerometerEventStream(
            samplingPeriod: SensorInterval.gameInterval,
          ).listen(
            (event) {
              if (_detector.add(event.x, event.y, event.z, DateTime.now())) {
                unawaited(_report());
              }
            },
            onError: (_) {},
            cancelOnError: false,
          );
    } else if (!listen && _sensor != null) {
      _sensor!.cancel();
      _sensor = null;
    }
  }

  Future<void> _report() async {
    if (_reporting || !mounted || !widget.canReport()) return;
    _reporting = true;
    try {
      final screenshot = await _capture();
      unawaited(AppHaptics.play(AppHaptics.confirm));
      if (mounted) widget.onShake(screenshot);
    } finally {
      _reporting = false;
    }
  }

  /// The screen as it is now, at a size readable in a report but small
  /// enough to upload quickly (well under the bucket's 3 MB limit).
  Future<Uint8List?> _capture() async {
    try {
      final boundary =
          _boundary.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || boundary.debugNeedsPaint) return null;
      final ratio = math.min(View.of(context).devicePixelRatio, 1.5);
      final image = await boundary.toImage(pixelRatio: ratio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(key: _boundary, child: widget.child);
  }
}
