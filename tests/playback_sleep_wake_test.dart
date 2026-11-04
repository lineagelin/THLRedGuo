import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:THLRedLook/utils/screen/screen_wake_controller.dart';
import 'package:THLRedLook/core/player/playback_sleep_timer.dart';

void main() {
  test(
    'expiry releases wake policy across resumes until explicit playback',
    () async {
      final applied = <bool>[];
      final wake = ScreenWakeController.forTesting(({required enable}) async {
        applied.add(enable);
      });
      var paused = false;
      final now = DateTime(2026, 11, 2);
      var time = now;
      Future<void>? expiration;
      final timer = PlaybackSleepTimer(
        now: () => time,
        onExpire: () {
          paused = true;
          expiration = wake.releaseForSleep();
        },
      );
      await wake.sync(true);
      timer.setDuration(const Duration(minutes: 5));
      time = now.add(const Duration(minutes: 5));
      timer.checkDeadline();
      await expiration;
      expect(paused, isTrue);
      expect(wake.isWakeLocked, isFalse);
      await wake.handleAppResume(true);
      expect(wake.isWakeLocked, isFalse);
      expect(applied.last, isFalse);
      await wake.resumePlayback();
      expect(applied.last, isTrue);
      await wake.sync(false);
      await wake.releaseForSleep();
      await wake.resumePlayback();
      expect(wake.isWakeLocked, isFalse);
      timer.dispose();
      wake.dispose();
    },
  );

  test('pending enable cannot overwrite sleep release', () async {
    final gate = Completer<void>();
    final applied = <bool>[];
    final wake = ScreenWakeController.forTesting(({required enable}) async {
      if (enable) await gate.future;
      applied.add(enable);
    });
    final enabling = wake.sync(true);
    await Future<void>.delayed(Duration.zero);
    final releasing = wake.releaseForSleep();
    final resuming = wake.handleAppResume(true);
    gate.complete();
    await Future.wait([enabling, releasing, resuming]);
    expect(applied, [true, false, false]);
    expect(wake.isWakeLocked, isFalse);
    wake.dispose();
  });
}
