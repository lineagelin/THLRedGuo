import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:THLRedLook/core/player/luna_exo_player.dart';
import 'package:THLRedLook/core/player/player_interactions.dart';
import 'package:THLRedLook/utils/theme/app_colors.dart';
import 'package:THLRedLook/views/player/player_episode_swipe_view.dart';

class _Harness extends StatefulWidget {
  const _Harness({super.key, this.initialIndex = 1, this.capture});
  final int initialIndex;
  final Future<ui.Image?> Function()? capture;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final page = GlobalKey<PlayerEpisodeSwipeViewState>();
  final player = LunaExoPlayer();
  late final PlayerInteractions interactions;
  late int index = widget.initialIndex;
  final selected = <int>[];
  final seeks = <Duration>[];
  bool ready = true;
  bool error = false;
  bool failSelection = false;
  int liveMounts = 0;
  int backCount = 0;

  @override
  void initState() {
    super.initState();
    player.state = player.state.copyWith(
      volume: 50,
      playing: true,
      duration: const Duration(minutes: 2),
      position: const Duration(seconds: 30),
    );
    interactions = PlayerInteractions(
      player: player,
      available: () => !(page.currentState?.switching ?? false),
      canSwipe: () => true,
      baseSpeed: () => 1,
      onTogglePlayback: () {},
      onFullscreen: () {},
      onSeek: (position) async => seeks.add(position),
      onEpisode: _select,
      onEpisodeSwipe: _select,
      onEpisodeDrag: (offset) => page.currentState?.updateDrag(offset),
      onEpisodeDragCancel: () => page.currentState?.cancelDrag(),
    );
  }

  String _select(int direction) {
    final next = index + direction;
    if (next < 0 || next > 2) {
      page.currentState?.cancelDrag();
      return '边界';
    }
    unawaited(page.currentState!.switchTo(next));
    return '第 ${next + 1} 集';
  }

  void firstFrame() => setState(() => ready = true);

  @override
  void dispose() {
    interactions.dispose();
    unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SizedBox.expand(
        child: PlayerEpisodeSwipeView(
          key: page,
          index: index,
          episodeCount: 3,
          frameReady: ready,
          hasError: error,
          captureFrame: widget.capture ?? () async => null,
          onBack: () => backCount++,
          onSelectEpisode: (next) async {
            selected.add(next);
            setState(() {
              index = next;
              ready = false;
              error = failSelection;
            });
            if (failSelection) throw StateError('load failed');
          },
          previewBuilder: (index, waiting) => ColoredBox(
            color: AppColors.darkSurface,
            child: Center(
              child: Text('preview-$index${waiting ? '-loading' : ''}'),
            ),
          ),
          child: LayoutBuilder(
            builder: (_, constraints) => Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => interactions.pointerDown(
                event,
                swipeEnabled: true,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
              onPointerMove: interactions.pointerMove,
              onPointerUp: interactions.pointerUp,
              onPointerCancel: interactions.pointerCancel,
              child: _LiveVideo(index: index, onMount: () => liveMounts++),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LiveVideo extends StatefulWidget {
  const _LiveVideo({required this.index, required this.onMount});
  final int index;
  final VoidCallback onMount;
  @override
  State<_LiveVideo> createState() => _LiveVideoState();
}

class _LiveVideoState extends State<_LiveVideo> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.blue,
    child: Center(child: Text('live-${widget.index}')),
  );
}

Future<_HarnessState> _mount(
  WidgetTester tester, {
  int index = 1,
  Future<ui.Image?> Function()? capture,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 640);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final key = GlobalKey<_HarnessState>();
  await tester.pumpWidget(
    _Harness(key: key, initialIndex: index, capture: capture),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  return key.currentState!;
}

double _translation(WidgetTester tester, String key) =>
    tester.widget<Transform>(find.byKey(ValueKey(key))).transform.storage[13];

Future<void> _swipe(WidgetTester tester, Offset start, Offset delta) async {
  final gesture = await tester.startGesture(start);
  await gesture.moveBy(delta);
  await gesture.up();
  await tester.pump();
}

class _VideoPlatform extends VideoPlayerPlatform {
  int _nextId = 0;
  final volumes = <double>[];
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      ++_nextId;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(minutes: 1),
      size: const Size(720, 1280),
    ),
  );
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async =>
      volumes.add(volume);
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
}

class _NativeProperties implements NativePlayer {
  final properties = <(String, String)>[];
  @override
  Future<void> setProperty(
    String property,
    String value, {
    bool waitForInitialization = true,
  }) async {
    properties.add((property, value));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StreamBackend extends LunaExoPlayer {
  final native = _NativeProperties();
  final opened = <Media>[];
  bool disposed = false;
  @override
  NativePlayer get platform => native;
  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    opened.add(playable as Media);
    state = state.copyWith(
      playing: play,
      width: 720,
      height: 1280,
      buffering: false,
      duration: const Duration(minutes: 1),
      position: Duration.zero,
    );
    stream.playingController.add(play);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    stream.dispose();
  }
}

void main() {
  for (final x in [40.0, 180.0, 320.0]) {
    testWidgets(
      'vertical swipe at x=$x changes episodes without changing volume',
      (tester) async {
        final h = await _mount(tester);
        await _swipe(tester, Offset(x, 400), const Offset(0, -120));
        expect(h.selected, [2]);
        expect(h.player.state.volume, 50);
        expect(h.interactions.hudState.type, SwipeAction.none);
        h.firstFrame();
        await tester.pumpAndSettle();
        await _swipe(tester, Offset(x, 200), const Offset(0, 150));
        expect(h.selected, [2, 1]);
        expect(h.player.state.volume, 50);
        expect(h.interactions.hudState.type, SwipeAction.none);
      },
    );
  }

  testWidgets(
    'cached first frame is exposed during slide without a loading flash',
    (tester) async {
      final h = await _mount(tester);
      await _swipe(tester, const Offset(180, 400), const Offset(0, -120));
      await tester.pump(const Duration(milliseconds: 50));
      h.firstFrame();
      await tester.pump();
      final cover = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('episode-frame-cover')),
      );
      expect(cover.opacity, 0);
      expect(_translation(tester, 'episode-live-page'), greaterThan(0));
      expect(find.text('preview-2-loading'), findsNothing);
      expect(h.liveMounts, 1);
      await tester.pumpAndSettle();
      expect(h.page.currentState!.switching, isFalse);
    },
  );

  test(
    'encrypted episode opens reuse backend and refresh the media key',
    () async {
      final backends = <_StreamBackend>[];
      final player = LunaExoPlayer(
        streamingPlayerFactory: () {
          final backend = _StreamBackend();
          backends.add(backend);
          return backend;
        },
        streamingVideoFactory: (_) => null,
      );
      final positions = <Duration>[];
      final subscription = player.stream.position.listen(positions.add);
      await player.setVolume(23);
      await player.setRate(1.5);
      const key1 = '00112233445566778899aabbccddeeff';
      const key2 = 'ffeeddccbbaa99887766554433221100';
      await player.open(
        Media(
          'http://127.0.0.1/cached-one.mp4',
          extras: {'decryptionKey': key1},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final backend = backends.single;
      await player.open(
        Media(
          'http://127.0.0.1/cached-two.mp4',
          extras: {'decryptionKey': key2},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(backends, hasLength(1));
      expect(backend.opened, hasLength(2));
      expect(backend.disposed, isFalse);
      expect(backend.state.volume, 23);
      expect(backend.state.rate, 1.5);
      expect(
        backend.native.properties
            .where((p) => p.$1 == 'demuxer-lavf-o')
            .map((p) => p.$2),
        ['decryption_key=$key1', 'decryption_key=$key2'],
      );
      backend.stream.positionController.add(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      expect(positions.last, const Duration(seconds: 2));
      await player.stop();
      expect(backend.disposed, isTrue);
      await player.open(
        Media('http://127.0.0.1/restart.mp4', extras: {'decryptionKey': key1}),
      );
      expect(backends, hasLength(2));
      await subscription.cancel();
      await player.dispose();
    },
  );

  testWidgets('horizontal swipes still seek', (tester) async {
    final h = await _mount(tester);
    await _swipe(tester, const Offset(240, 400), const Offset(90, -10));
    expect(h.seeks.single, greaterThan(const Duration(seconds: 30)));
    expect(h.selected, isEmpty);
    expect(h.player.state.volume, 50);
  });

  testWidgets(
    'center follows finger, slides next page, and waits for the first frame',
    (tester) async {
      final h = await _mount(tester);
      final gesture = await tester.startGesture(const Offset(180, 400));
      await gesture.moveBy(const Offset(0, -120));
      await tester.pump();
      expect(_translation(tester, 'episode-live-page'), -120);
      expect(_translation(tester, 'episode-incoming-page'), 520);
      await gesture.up();
      await tester.pump();
      expect(h.selected, [2]);
      await tester.pump(const Duration(milliseconds: 140));
      expect(_translation(tester, 'episode-outgoing-page'), lessThan(-120));
      expect(_translation(tester, 'episode-outgoing-page'), greaterThan(-640));
      await tester.pumpAndSettle();
      expect(_translation(tester, 'episode-incoming-page'), closeTo(0, .01));
      expect(h.page.currentState!.switching, isTrue);
      expect(find.text('preview-2-loading'), findsNothing);
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('preview-2-loading'), findsOneWidget);
      expect(h.liveMounts, 1);
      h.firstFrame();
      await tester.pumpAndSettle();
      expect(h.page.currentState!.switching, isFalse);
      expect(find.byKey(const ValueKey('episode-incoming-page')), findsNothing);
      expect(_translation(tester, 'episode-live-page'), 0);
      expect(h.liveMounts, 1);
    },
  );

  testWidgets(
    'outgoing captured image stays present across decoder replacement',
    (tester) async {
      final image = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(AppColors.blue, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(2, 2);
        picture.dispose();
        return image;
      });
      final h = await _mount(tester, capture: () async => image);
      await _swipe(tester, const Offset(180, 400), const Offset(0, -120));
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, same(image));
      await tester.pumpAndSettle();
      expect(h.page.currentState!.switching, isTrue);
      h.firstFrame();
      await tester.pumpAndSettle();
      expect(find.byType(RawImage), findsNothing);
      expect(image!.debugDisposed, isTrue);
    },
  );

  testWidgets('short and cancelled swipes bounce back without loading', (
    tester,
  ) async {
    final h = await _mount(tester);
    await _swipe(tester, const Offset(180, 400), const Offset(0, -24));
    await tester.pumpAndSettle();
    expect(h.selected, isEmpty);
    expect(_translation(tester, 'episode-live-page'), 0);
    final gesture = await tester.startGesture(const Offset(180, 400));
    await gesture.moveBy(const Offset(0, -120));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(h.selected, isEmpty);
    expect(_translation(tester, 'episode-live-page'), 0);
  });

  for (final boundary in [0, 2]) {
    testWidgets(
      'episode boundary $boundary resists and returns without wrapping',
      (tester) async {
        final h = await _mount(tester, index: boundary);
        final gesture = await tester.startGesture(const Offset(180, 300));
        await gesture.moveBy(Offset(0, boundary == 0 ? 120 : -120));
        await tester.pump();
        expect(
          _translation(tester, 'episode-live-page').abs(),
          closeTo(21.6, .01),
        );
        expect(
          find.byKey(const ValueKey('episode-incoming-page')),
          findsNothing,
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(h.selected, isEmpty);
        expect(_translation(tester, 'episode-live-page'), 0);
      },
    );
  }

  testWidgets(
    'loading transition accepts another swipe and switches to the latest episode',
    (tester) async {
      final h = await _mount(tester);
      await _swipe(tester, const Offset(180, 300), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(h.selected, [0]);
      await _swipe(tester, const Offset(180, 400), const Offset(0, -120));
      expect(h.selected, [0, 1]);
      expect(h.liveMounts, 1);
      await tester.tap(find.byTooltip('退出播放'));
      expect(h.backCount, 1);
      h.firstFrame();
      await tester.pumpAndSettle();
      expect(h.page.currentState!.switching, isFalse);
    },
  );

  testWidgets(
    'a new drag interrupts bounce without being reset by old animation',
    (tester) async {
      final h = await _mount(tester);
      await _swipe(tester, const Offset(180, 400), const Offset(0, -24));
      await tester.pump(const Duration(milliseconds: 60));
      final gesture = await tester.startGesture(const Offset(180, 400));
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();
      expect(_translation(tester, 'episode-live-page'), -100);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(h.selected, [2]);
    },
  );

  testWidgets(
    'load failure releases transition and route disposal cancels late capture',
    (tester) async {
      final h = await _mount(tester);
      h.failSelection = true;
      await _swipe(tester, const Offset(180, 400), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(h.page.currentState!.switching, isFalse);
      expect(tester.takeException(), isNull);
      final capture = Completer<ui.Image?>();
      final next = await _mount(tester, capture: () => capture.future);
      await _swipe(tester, const Offset(180, 400), const Offset(0, -120));
      await tester.pumpWidget(const SizedBox());
      capture.complete(null);
      await tester.pumpAndSettle();
      expect(next.selected, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('native controller keeps chosen volume across media opens', (
    tester,
  ) async {
    final previous = VideoPlayerPlatform.instance;
    final platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
    final player = LunaExoPlayer();
    try {
      await tester.runAsync(() async {
        await player.setVolume(23);
        await player.open(Media('file:///C:/gesture-test-1.mp4'), play: false);
        expect(platform.volumes.last, .23);
        await player.stop();
        await player.open(Media('file:///C:/gesture-test-2.mp4'), play: false);
        expect(platform.volumes.last, .23);
        await player.dispose();
      });
    } finally {
      await tester.runAsync(player.dispose);
      VideoPlayerPlatform.instance = previous;
    }
  });
}
