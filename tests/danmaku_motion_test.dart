import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:THLRedLook/core/bridge/core_bridge.dart';
import 'package:THLRedLook/core/danmaku/danmaku_controller.dart';
import 'package:THLRedLook/models/catalog/models.dart';
import 'package:THLRedLook/models/danmaku/danmaku_models.dart';
import 'package:THLRedLook/views/danmaku/danmaku_overlay.dart';

class _Repository implements AppRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OverlayController extends DanmakuController {
  _OverlayController() : super(_Repository()) {
    items = const [DanmakuItem(id: 'motion', text: '连续滚动测试', timeMs: 0)];
    durationMs = 30000;
  }
  bool running = true;
  @override
  bool get visible => true;
  @override
  bool get moving => running;
  @override
  int get motionPositionMs => positionMs;

  void report(int position, {bool? playing, double? speed, bool seek = false}) {
    positionMs = position;
    if (playing != null) {
      running = playing;
    }
    if (speed != null) {
      rate = speed;
    }
    if (seek) motionRevision++;
    notifyListeners();
  }
}

void main() {
  double x(WidgetTester tester) => tester
      .widget<Transform>(find.byKey(const ValueKey('danmaku-motion-motion')))
      .transform
      .storage[12];

  Future<_OverlayController> mount(WidgetTester tester) async {
    final controller = _OverlayController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: DanmakuOverlay(
            controller: controller,
            aspectRatio: 1,
            style: const DanmakuStyle(highRefreshRate: false),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('normal progress jitter does not snap a running flight', (
    tester,
  ) async {
    final controller = await mount(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final before = x(tester);
    controller.report(360);
    await tester.pump();
    expect(x(tester), closeTo(before, .001));
    await tester.pump(const Duration(microseconds: 8333));
    expect(x(tester), lessThan(before));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('flight keeps moving past 750ms without a progress callback', (
    tester,
  ) async {
    await mount(tester);
    await tester.pump(const Duration(seconds: 1));
    final before = x(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(x(tester), lessThan(before));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pause freezes, resume and speed changes restart correctly', (
    tester,
  ) async {
    final controller = await mount(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final beforePause = x(tester);
    controller.report(360, playing: false);
    await tester.pump();
    final paused = x(tester);
    expect(paused, closeTo(beforePause, .001));
    await tester.pump(const Duration(seconds: 1));
    expect(x(tester), paused);
    controller.report(365, playing: true, speed: 2);
    await tester.pump();
    expect(x(tester), closeTo(paused, .001));
    await tester.pump(const Duration(milliseconds: 100));
    final atDoubleSpeed = x(tester);
    expect(atDoubleSpeed, lessThan(paused));
    controller.report(2400, seek: true);
    await tester.pump();
    expect(x(tester), lessThan(atDoubleSpeed));
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'continuous clock ignores small sample jitter but reanchors on seeks',
    () {
      var now = DateTime(2026);
      final controller = DanmakuController(_Repository(), now: () => now);
      addTearDown(controller.dispose);
      controller.setPlan(
        const PlaybackPlan(
          url: 'https://example.test/video',
          session: 'test',
          danmakuId: 'episode',
        ),
      );
      void update(int position, {bool seek = false, bool playing = true}) =>
          controller.update(
            position: Duration(milliseconds: position),
            duration: const Duration(seconds: 30),
            speed: 1,
            playing: playing,
            buffering: false,
            foreground: true,
            available: true,
            discontinuity: seek,
          );
      update(1000);
      final revision = controller.motionRevision;
      now = now.add(const Duration(milliseconds: 400));
      update(1360);
      expect(controller.motionRevision, revision);
      expect(controller.motionPositionMs, 1400);
      now = now.add(const Duration(milliseconds: 100));
      update(1440, playing: false);
      expect(controller.motionPositionMs, 1500);
      now = now.add(const Duration(seconds: 1));
      update(1480, playing: false);
      expect(controller.motionPositionMs, 1500);
      expect(controller.motionRevision, revision);
      update(1480);
      expect(controller.motionPositionMs, 1500);
      now = now.add(const Duration(milliseconds: 200));
      expect(controller.motionPositionMs, 1700);
      update(6000, seek: true);
      expect(controller.motionRevision, greaterThan(revision));
      expect(controller.motionPositionMs, 6000);
    },
  );

  testWidgets(
    'high refresh preference releases on pause, background and disposal',
    (tester) async {
      const channel = MethodChannel('duanju/device');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final controller = _OverlayController();
      addTearDown(controller.dispose);
      Future<void> mount(bool enabled) => tester.pumpWidget(
        MaterialApp(
          home: DanmakuOverlay(
            controller: controller,
            aspectRatio: 1,
            style: DanmakuStyle(highRefreshRate: enabled),
          ),
        ),
      );
      await mount(true);
      expect(calls.last.arguments['enabled'], true);
      controller.report(100, playing: false);
      await tester.pump();
      expect(calls.last.arguments['enabled'], false);
      controller.report(100, playing: true);
      await tester.pump();
      expect(calls.last.arguments['enabled'], true);
      await mount(false);
      expect(calls.last.arguments['enabled'], false);
      await mount(true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(calls.last.arguments['enabled'], false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls.last.arguments['enabled'], true);
      await tester.pumpWidget(const SizedBox());
      expect(calls.last.arguments['enabled'], false);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
