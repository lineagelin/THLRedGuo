import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:THLRedLook/core/js/hongguo_guest_session.dart';

String session(int n) => jsonEncode({
  'iid': '${10000000000 + n}',
  'device_id': '${20000000000 + n}',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late SharedPreferences prefs;
  late HongguoGuestSession guest;

  setUp(() async {
    now = DateTime(2026, 11, 1, 2);
    SharedPreferences.setMockInitialValues({
      HongguoGuestSession.sessionKey: session(1),
      HongguoGuestSession.createdKey: now
          .subtract(const Duration(minutes: 30))
          .millisecondsSinceEpoch,
      'favorites': 'saved favorites',
      'history': 'saved progress',
    });
    prefs = await SharedPreferences.getInstance();
    guest = HongguoGuestSession(now: () => now);
    await guest.preload();
  });

  test('even a recently created rejected guest can recover', () async {
    await prefs.setInt(
      HongguoGuestSession.createdKey,
      now.millisecondsSinceEpoch,
    );
    final recent = HongguoGuestSession(now: () => now);
    await recent.preload();
    expect(
      await recent.invalidateForPlayback(session(1)),
      GuestRecoveryDecision.renew,
    );
  });

  test(
    'failed recovery clears only guest cache and backs off across restarts',
    () async {
      expect(
        await guest.invalidateForPlayback(session(1)),
        GuestRecoveryDecision.renew,
      );
      expect(guest.value, isNull);
      expect(prefs.getString('favorites'), 'saved favorites');
      expect(prefs.getString('history'), 'saved progress');
      guest.accept(session(2));
      await guest.pendingWrites;
      final restarted = HongguoGuestSession(now: () => now);
      await restarted.preload();
      expect(
        await restarted.invalidateForPlayback(session(2)),
        GuestRecoveryDecision.none,
      );
      expect(restarted.value, session(2));
      now = now.add(HongguoGuestSession.failedRecoveryBackoff);
      expect(
        await restarted.invalidateForPlayback(session(2)),
        GuestRecoveryDecision.renew,
      );
    },
  );

  test(
    'successful recovery allows a second rejected video to recover immediately',
    () async {
      expect(
        await guest.invalidateForPlayback(session(1)),
        GuestRecoveryDecision.renew,
      );
      guest.accept(session(2));
      await guest.pendingWrites;
      await guest.playbackSucceeded(session(2));
      expect(prefs.getInt(HongguoGuestSession.recoveryKey), isNull);
      expect(
        await guest.invalidateForPlayback(session(2)),
        GuestRecoveryDecision.renew,
      );
      expect(prefs.getString('favorites'), 'saved favorites');
      expect(prefs.getString('history'), 'saved progress');
    },
  );

  test('adopts newer persisted identity instead of discarding it', () async {
    await prefs.setString(HongguoGuestSession.sessionKey, session(2));
    await prefs.setInt(
      HongguoGuestSession.createdKey,
      now.millisecondsSinceEpoch,
    );
    expect(
      await guest.invalidateForPlayback(session(1)),
      GuestRecoveryDecision.reload,
    );
    expect(guest.value, session(2));
    expect(prefs.getInt(HongguoGuestSession.recoveryKey), isNull);
  });

  test(
    'concurrent recovery requests cannot consume multiple renewals',
    () async {
      final results = await Future.wait([
        guest.invalidateForPlayback(session(1)),
        guest.invalidateForPlayback(session(1)),
      ]);
      expect(
        results.where((value) => value == GuestRecoveryDecision.renew),
        hasLength(1),
      );
      guest.accept(session(2));
      await guest.pendingWrites;
      expect(
        await guest.invalidateForPlayback(session(1)),
        GuestRecoveryDecision.reload,
      );
      expect(guest.value, session(2));
    },
  );

  test(
    'accepting a concurrent new identity wins over invalidating old identity',
    () async {
      final pending = guest.invalidateForPlayback(session(1));
      guest.accept(session(2));
      expect(await pending, GuestRecoveryDecision.reload);
      await guest.pendingWrites;
      expect(guest.value, session(2));
      expect(prefs.getString(HongguoGuestSession.sessionKey), session(2));
    },
  );
}
