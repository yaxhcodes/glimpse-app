import 'dart:math' as math;

/// Recognises a deliberate shake from linear-acceleration samples (gravity
/// removed, m/s²). A shake is a quick back-and-forth, so it is counted as
/// several strong peaks close together: walking (~3-6 m/s²), running or a
/// car on a bad road (~10-15 m/s²) stay under the threshold or don't
/// repeat fast enough. After a shake fires it stays quiet for a cooldown.
class ShakeDetector {
  ShakeDetector({
    this.threshold = 22,
    this.requiredPeaks = 3,
    this.window = const Duration(milliseconds: 1200),
    this.minPeakGap = const Duration(milliseconds: 100),
    this.cooldown = const Duration(seconds: 3),
  });

  /// Acceleration (m/s², gravity removed) a swing must exceed to count.
  final double threshold;

  /// Peaks that make a shake: three is one firm back-and-forth and a half.
  final int requiredPeaks;

  /// The peaks must all fall within this span.
  final Duration window;

  /// One swing crosses the threshold for several samples; peaks closer
  /// than this are the same swing.
  final Duration minPeakGap;

  /// Quiet time after a shake fires.
  final Duration cooldown;

  final List<DateTime> _peaks = [];
  DateTime? _lastFired;

  /// Feeds one sample; true when it completes a shake.
  bool add(double x, double y, double z, DateTime at) {
    final lastFired = _lastFired;
    if (lastFired != null && at.difference(lastFired) < cooldown) {
      return false;
    }
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (magnitude < threshold) return false;
    if (_peaks.isNotEmpty && at.difference(_peaks.last) < minPeakGap) {
      return false;
    }
    _peaks
      ..add(at)
      ..removeWhere((peak) => at.difference(peak) > window);
    if (_peaks.length < requiredPeaks) return false;
    _peaks.clear();
    _lastFired = at;
    return true;
  }

  void reset() {
    _peaks.clear();
  }
}
