import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// A sleep timer overrides the saved wake preference until playback resumes.
class ScreenWakeController extends ChangeNotifier {
  ScreenWakeController._() : _apply = WakelockPlus.toggle;
  @visibleForTesting
  ScreenWakeController.forTesting(
    Future<void> Function({required bool enable}) apply,
  ) : _apply = apply;
  static final instance = ScreenWakeController._();
  final Future<void> Function({required bool enable}) _apply;
  bool _requested = false;
  bool _sleepReleased = false;
  bool _isWakeLocked = false;
  Future<void> _pending = Future.value();
  bool get isWakeLocked => _isWakeLocked;

  Future<void> sync(bool keepScreenOn) {
    _requested = keepScreenOn;
    return _sync();
  }

  Future<void> releaseForSleep() {
    _sleepReleased = true;
    return _sync();
  }

  Future<void> resumePlayback() {
    if (!_sleepReleased) return _pending;
    _sleepReleased = false;
    return _sync();
  }

  Future<void> handleAppResume(bool keepScreenOn) => sync(keepScreenOn);
  Future<void> _sync() {
    // An older enable must never win against timer expiry.
    return _pending = _pending.then((_) async {
      final enabled = _requested && !_sleepReleased;
      try {
        await _apply(enable: enabled);
      } catch (_) {
        // Retain the policy on unsupported platforms too.
      }
      _isWakeLocked = enabled;
      notifyListeners();
    });
  }
}
