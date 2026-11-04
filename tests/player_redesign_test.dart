import 'package:THLRedLook/core/store/follow_state.dart';
import 'package:THLRedLook/views/feed/feed_player_overlay.dart';
import 'package:THLRedLook/utils/screen/app_layout.dart';
import 'dart:convert';
import 'package:THLRedLook/core/feed/video_feed_controller.dart';
import 'package:THLRedLook/models/feed/feed_models.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:THLRedLook/core/bridge/core_bridge.dart';
import 'package:THLRedLook/core/player/luna_exo_player.dart';
import 'package:THLRedLook/core/player/playback_preferences.dart';
import 'package:THLRedLook/core/player/playback_sleep_timer.dart';
import 'package:THLRedLook/core/player/player_interactions.dart';
import 'package:THLRedLook/core/store/local_store.dart';
import 'package:THLRedLook/models/catalog/models.dart';
import 'package:THLRedLook/pages/detail/detail_page.dart';
import 'package:THLRedLook/pages/player/playback_launch_page.dart';
import 'package:THLRedLook/pages/player/player_page.dart';
import 'package:THLRedLook/utils/theme/app_colors.dart';
import 'package:THLRedLook/utils/theme/app_theme.dart';
import 'package:THLRedLook/views/drama/drama_mobile_detail_view.dart';
import 'package:THLRedLook/views/player/player_portrait_overlay.dart';
import 'package:THLRedLook/views/player/player_quick_menu_sheet.dart';

const _capture = bool.fromEnvironment('PLAYER_LAYOUT_SCREENSHOTS');
const _drama = Drama(
  id: 'hongguo:fixture',
  sourceId: 'fixture',
  source: 'hongguo',
  title: '测试剧集',
  description: '这里展示接口返回的真实简介。没有返回的评分和社交计数不显示。',
  category: '都市',
  tags: ['家庭'],
  heat: '123万',
  releaseStatus: 'finished',
);
final _detail = DramaDetail(_drama, [
  for (var i = 1; i <= 3; i++)
    Episode({'id': 'ep$i', 'currentEpisode': i, 'title': '第$i集'}, i),
]);
final _preview = GlobalKey();

class _Repository extends AppRepository {
  int detailCalls = 0;
  bool empty = false;
  @override
  Future<DramaDetail> detail(Drama drama) async {
    detailCalls++;
    return empty ? DramaDetail(_drama, []) : _detail;
  }

  @override
  Future<PlaybackPlan> resolve(
    Drama drama,
    Episode episode, {
    int quality = 0,
  }) async => const PlaybackPlan(
    url: 'file:///C:/fixture.mp4',
    quality: 720,
    qualities: [720, 1080],
  );
  @override
  Future<void> release(String session) async {}
  @override
  Future<String> cover(Drama drama, {bool force = false}) async => '';
  @override
  Future<CatalogPage> recommendations(
    String genre, {
    String? source,
    bool more = false,
    bool force = false,
  }) async => CatalogPage([
    const Drama(id: 'hongguo:other', source: 'hongguo', title: '接口返回的推荐'),
  ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player extends LunaExoPlayer {
  int opens = 0;
  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    opens++;
    state = state.copyWith(
      playing: play,
      buffering: false,
      width: 720,
      height: 1280,
      duration: const Duration(minutes: 2),
      position: const Duration(seconds: 12),
    );
    stream.positionController.add(state.position);
    stream.playingController.add(play);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(playing: false);
    stream.playingController.add(false);
  }

  @override
  Future<void> play() async {
    state = state.copyWith(playing: true);
    stream.playingController.add(true);
  }
}

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final image =
        await (_preview.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/player-redesign').createSync(recursive: true);
    await File(
      'build/player-redesign/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

ThemeData _theme() => _capture
    ? AppTheme.light.copyWith(
        textTheme: AppTheme.light.textTheme.apply(fontFamily: 'PreviewChinese'),
      )
    : AppTheme.light;
void _screen(WidgetTester tester, [Size size = const Size(390, 844)]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<LocalStore> _store() async {
  SharedPreferences.setMockInitialValues({'keepScreenOn': false});
  return LocalStore(await SharedPreferences.getInstance());
}

void main() {
  setUpAll(() async {
    if (_capture) {
      final font = FontLoader('PreviewChinese')
        ..addFont(
          File(
            'C:/Windows/Fonts/msyh.ttc',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await font.load();
      final darkFont = FontLoader('Hiragino Sans GB')
        ..addFont(
          File(
            'C:/Windows/Fonts/msyh.ttc',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await darkFont.load();
      final root =
          Platform.environment['FLUTTER_ROOT'] ?? 'D:/Program Files/flutter';
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await icons.load();
    }
  });

  test(
    'feed reactivation retains detail without requesting it again',
    () async {
      final repo = _Repository();
      final store = await _store();
      final feed = VideoFeedController(repo, store);
      feed.items = [const FeedItem(drama: _drama)];
      feed.setActive(true);
      await feed.prepare();
      await Future<void>.delayed(Duration.zero);
      expect(repo.detailCalls, 1);
      final detail = feed.detail;
      feed.setActive(false);
      expect(feed.detail, same(detail));
      feed.setActive(true);
      feed.select(0);
      await Future<void>.delayed(Duration.zero);
      expect(repo.detailCalls, 1);
      expect(feed.detail, same(detail));
      feed.dispose();
      store.dispose();
    },
  );

  testWidgets(
    'inactive feed pauses and resumes the same player without reopening media',
    (tester) async {
      _screen(tester);
      final repo = _Repository();
      final store = await _store();
      final player = _Player();
      var active = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setter) {
              update = setter;
              return PlayerScreen(
                key: const ValueKey('retained-feed-player'),
                detail: _detail,
                initialIndex: 0,
                repository: repo,
                store: store,
                feed: true,
                feedActive: active,
                playerFactory: () => player,
                videoBuilder: (controls) => Material(child: controls),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(player.opens, 1);
      final position = player.state.position;
      update(() => active = false);
      await tester.pumpAndSettle();
      expect(player.state.playing, isFalse);
      expect(player.opens, 1);
      update(() => active = true);
      await tester.pumpAndSettle();
      expect(player.state.playing, isTrue);
      expect(player.state.position, position);
      expect(player.opens, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      store.dispose();
    },
  );

  for (final saved in [false, true]) {
    testWidgets(
      'last episode EOF marks ${saved ? 'followed' : 'unfollowed'} drama watched and survives reload',
      (tester) async {
        _screen(tester);
        final store = await _store();
        if (saved) await store.setFollowStatus(_drama, FollowStatus.watching);
        final player = _Player();
        await tester.pumpWidget(
          MaterialApp(
            home: PlayerScreen(
              detail: _detail,
              initialIndex: 2,
              repository: _Repository(),
              store: store,
              playerFactory: () => player,
              videoBuilder: (controls) => Material(child: controls),
            ),
          ),
        );
        await tester.pumpAndSettle();
        player.state = player.state.copyWith(
          position: const Duration(milliseconds: 118500),
          completed: true,
          playing: false,
        );
        player.stream.positionController.add(player.state.position);
        player.stream.completedController.add(true);
        await tester.pumpAndSettle();
        expect(store.following(_drama.id)?.status, FollowStatus.watched);
        expect(store.following(_drama.id)?.manuallyWatched, isFalse);
        expect(store.following(_drama.id)?.knownEpisodes, 3);
        expect(store.watched(_drama.id)?.position, 120);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        store.dispose();
        final restored = LocalStore(await SharedPreferences.getInstance());
        expect(restored.following(_drama.id)?.status, FollowStatus.watched);
        final updated = Drama.fromJson({..._drama.toJson(), 'episodes': 4});
        expect(
          restored.following(_drama.id)!.observe(updated).status,
          FollowStatus.watching,
        );
        restored.dispose();
      },
    );
  }

  for (final scenario in [(0, 118500), (2, 20000)]) {
    testWidgets(
      'does not mark watched for episode ${scenario.$1 + 1} ending at ${scenario.$2}ms',
      (tester) async {
        _screen(tester);
        final store = await _store();
        await store.setPlaybackPreferences(
          store.playbackPreferences.copyWith(autoAdvance: false),
        );
        final player = _Player();
        await tester.pumpWidget(
          MaterialApp(
            home: PlayerScreen(
              detail: _detail,
              initialIndex: scenario.$1,
              repository: _Repository(),
              store: store,
              playerFactory: () => player,
              videoBuilder: (controls) => Material(child: controls),
            ),
          ),
        );
        await tester.pumpAndSettle();
        player.state = player.state.copyWith(
          position: Duration(milliseconds: scenario.$2),
          completed: true,
        );
        player.stream.positionController.add(player.state.position);
        player.stream.completedController.add(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(store.following(_drama.id), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        store.dispose();
      },
    );
  }

  testWidgets('selecting sleep duration sends the requested Android toast', (
    tester,
  ) async {
    _screen(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final messages = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppDevice.channel, (call) async {
          if (call.method == 'showToast') {
            messages.add((call.arguments as Map)['message'] as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AppDevice.channel, null),
    );
    final store = await _store();
    final player = _Player();
    Future<void> Function()? menu;
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(),
        home: PlayerScreen(
          detail: _detail,
          initialIndex: 0,
          repository: _Repository(),
          store: store,
          feed: true,
          playerFactory: () => player,
          onMenuChanged: (value) => menu = value,
          videoBuilder: (controls) => Material(child: controls),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final opening = menu!();
    await tester.pumpAndSettle();
    final sleep = find.byKey(const ValueKey('quick-sleep'));
    await tester.ensureVisible(sleep);
    await tester.tap(sleep);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 分钟后'));
    await tester.pumpAndSettle();
    await opening;
    expect(messages, ['5分钟后关闭']);
    expect(player.state.playing, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    store.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'recommendation clear-screen remains reachable after removing its menu item',
    (tester) async {
      _screen(tester);
      var clean = false;
      var playing = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => FeedPlayerOverlay(
                title: '推荐剧名',
                episodeText: '第1集 · 全20集',
                description: '简介',
                playing: playing,
                enabled: true,
                following: false,
                danmakuEnabled: true,
                position: Duration.zero,
                duration: const Duration(minutes: 1),
                cleanScreen: clean,
                onCleanScreen: () => update(() => clean = !clean),
                onTogglePlayback: () => update(() => playing = !playing),
                onSeek: (_) {},
                onFavorite: () {},
                onEpisodes: () {},
                onDetail: () {},
                onDanmaku: () {},
                onSettings: () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('清屏播放'));
      await tester.pumpAndSettle();
      expect(clean, isTrue);
      expect(find.byKey(const ValueKey('feed-current-episode')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('feed-play-surface')));
      await tester.pumpAndSettle();
      expect(playing, isFalse);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await tester.tap(find.byTooltip('退出清屏'));
      await tester.pumpAndSettle();
      expect(clean, isFalse);
      expect(find.text('推荐剧名'), findsOneWidget);
    },
  );

  testWidgets(
    'sleep timer expires once, can cancel, and checks deadlines after suspension',
    (tester) async {
      var now = DateTime(2026, 10, 31, 20);
      var stopped = 0;
      final timer = PlaybackSleepTimer(
        onExpire: () => stopped++,
        now: () => now,
      );
      timer.setDuration(const Duration(minutes: 5));
      expect(timer.label, '5分钟后停止');
      timer.setDuration(null);
      now = now.add(const Duration(minutes: 10));
      timer.checkDeadline();
      expect(stopped, 0);
      timer.setDuration(const Duration(minutes: 15));
      now = now.add(const Duration(minutes: 16));
      timer.checkDeadline();
      timer.checkDeadline();
      expect(stopped, 1);
      expect(timer.deadline, isNull);
      timer.dispose();
    },
  );

  test(
    'retired text preference migrates to standard without changing PIP or decoder',
    () {
      const prefs = PlaybackPreferences(
        pictureInPicture: true,
        playerTextScale: 1.3,
        decoderMode: PlaybackDecoderMode.compatible,
      );
      final restored = PlaybackPreferences.fromJson(
        jsonDecode(jsonEncode(prefs.toJson())) as Map<String, dynamic>,
      );
      expect(restored.playerTextScale, 1.0);
      expect(restored.pictureInPicture, isTrue);
      expect(restored.decoderMode, PlaybackDecoderMode.compatible);
    },
  );

  testWidgets(
    'hold doubles speed; upward locks and downward unlocks without switching episodes',
    (tester) async {
      final player = _Player();
      player.state = player.state.copyWith(playing: true);
      var speed = 1.0;
      var episodes = 0;
      final interactions = PlayerInteractions(
        player: player,
        available: () => true,
        baseSpeed: () => speed,
        onTogglePlayback: () {},
        onFullscreen: () {},
        onEpisode: (_) {
          episodes++;
          return '';
        },
        onSpeedLock: (value) async => speed = value,
      );
      void down(int id) => interactions.pointerDown(
        PointerDownEvent(pointer: id, position: const Offset(100, 300)),
        swipeEnabled: true,
        width: 390,
        height: 844,
      );
      void up(int id) => interactions.pointerUp(
        PointerUpEvent(pointer: id, position: const Offset(100, 300)),
      );
      down(1);
      await tester.pump(const Duration(milliseconds: 400));
      await interactions.pendingRates;
      expect(player.state.rate, 2);
      up(1);
      await interactions.pendingRates;
      expect(player.state.rate, 1);
      down(2);
      await tester.pump(const Duration(milliseconds: 400));
      interactions.pointerMove(
        const PointerMoveEvent(pointer: 2, position: Offset(100, 200)),
      );
      await tester.pump();
      up(2);
      await interactions.pendingRates;
      expect(speed, 2);
      expect(player.state.rate, 2);
      down(3);
      await tester.pump(const Duration(milliseconds: 400));
      interactions.pointerMove(
        const PointerMoveEvent(pointer: 3, position: Offset(100, 400)),
      );
      await tester.pump();
      up(3);
      await interactions.pendingRates;
      expect(speed, 1);
      expect(player.state.rate, 1);
      expect(episodes, 0);
      interactions.dispose();
      await player.dispose();
    },
  );

  testWidgets(
    'quick menu exposes actual qualities and supported screenshot actions',
    (tester) async {
      _screen(tester);
      var prefs = const PlaybackPreferences(
        pictureInPicture: true,
        decoderMode: PlaybackDecoderMode.compatible,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: _preview,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => PlayerQuickMenuSheet.show(
                    context,
                    preferences: prefs,
                    qualities: [720, 1080],
                    onPreferences: (next) async => prefs = next,
                    danmakuSupported: true,
                    canDownload: false,
                    canCast: false,
                    canPip: false,
                    cleanScreen: false,
                    sleepLabel: '未开启',
                  ),
                  child: const Text('菜单'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('菜单'));
      await tester.pumpAndSettle();
      expect(find.text('播放菜单'), findsNothing);
      expect(find.byTooltip('关闭播放菜单'), findsNothing);
      expect(find.byKey(const ValueKey('quick-fontSize')), findsNothing);
      expect(find.byKey(const ValueKey('quick-cleanScreen')), findsNothing);
      expect(find.text('1x'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quick-speed-1.5')));
      await tester.pumpAndSettle();
      expect(prefs.speed, 1.5);
      expect(find.text('360P'), findsNothing);
      expect(find.text('720P'), findsOneWidget);
      expect(find.text('540P'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('quick-options-清晰度')),
          matching: find.byType(ChoiceChip),
        ),
        findsNothing,
      );
      final speedRect = tester.getRect(
        find.byKey(const ValueKey('quick-options-倍速')),
      );
      final qualityRect = tester.getRect(
        find.byKey(const ValueKey('quick-options-清晰度')),
      );
      expect(speedRect.left, qualityRect.left);
      expect(speedRect.right, qualityRect.right);
      expect(speedRect.height, greaterThanOrEqualTo(64));
      expect(qualityRect.height, greaterThanOrEqualTo(64));
      await _screenshot(tester, 'quick-menu');
      await tester.tap(find.byKey(const ValueKey('quick-quality-720')));
      await tester.pumpAndSettle();
      expect(prefs.quality, 720);
      expect(prefs.pictureInPicture, isTrue);
      expect(prefs.decoderMode, PlaybackDecoderMode.compatible);
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('quick-download')))
            .enabled,
        isFalse,
      );
      for (final action in ['cast', 'sleep']) {
        final finder = find.byKey(ValueKey('quick-$action'));
        await tester.ensureVisible(finder);
        expect(finder, findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'direct launch skips detail; title opens detail and selecting episode reuses player',
    (tester) async {
      _screen(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final repo = _Repository();
      final store = await _store();
      final player = _Player();
      var creations = 0;
      await tester.pumpWidget(
        RepaintBoundary(
          key: _preview,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _theme(),
            home: PlaybackLaunchScreen(
              drama: _drama,
              repository: repo,
              store: store,
              playerFactory: () {
                creations++;
                return player;
              },
              videoBuilder: (controls) => Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.playerSceneDark),
                  controls,
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(find.byType(DetailScreen), findsNothing);
      expect(find.byType(PlayerPortraitOverlay), findsOneWidget);
      expect(repo.detailCalls, 1);
      expect(creations, 1);
      await _screenshot(tester, 'portrait-player');
      tester.view.physicalSize = const Size(320, 640);
      await store.setPlaybackPreferences(
        store.playbackPreferences.copyWith(playerTextScale: 1.3),
      );
      player.stream.videoParamsController.add(
        const VideoParams(w: 1280, h: 720, dw: 1280, dh: 720),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await store.setPlaybackPreferences(
        store.playbackPreferences.copyWith(playerTextScale: 1),
      );
      player.stream.videoParamsController.add(
        const VideoParams(w: 720, h: 1280, dw: 720, dh: 1280),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('player-drama-title')));
      await tester.pumpAndSettle();
      expect(find.byType(DramaMobileDetailView), findsOneWidget);
      expect(player.state.playing, isFalse);
      expect(
        find.text('123万热度'),
        findsNothing,
      ); // Metadata is combined with actual episode count and status.
      expect(find.textContaining('123万热度'), findsOneWidget);
      expect(find.textContaining('8.7'), findsNothing);
      await _screenshot(tester, 'drama-detail');
      await tester.tap(find.byKey(const ValueKey('mobile-detail-episode-1')));
      await tester.pumpAndSettle();
      expect(find.byType(DetailScreen), findsNothing);
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(creations, 1);
      expect(player.opens, 2);
      expect(find.text('第2集'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('portrait-menu')));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerQuickMenuSheet), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      store.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('empty chapter response shows no invented playable episodes', (
    tester,
  ) async {
    _screen(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final repo = _Repository()..empty = true;
    final store = await _store();
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(),
        home: DetailScreen(
          drama: const Drama(
            id: 'hongguo:fixture',
            source: 'hongguo',
            title: '无分集测试',
            episodes: 273,
          ),
          repository: repo,
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final view = tester.widget<DramaMobileDetailView>(
      find.byType(DramaMobileDetailView),
    );
    expect(view.episodes, isEmpty);
    expect(find.byKey(const ValueKey('mobile-detail-episode-0')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'clean screen keeps episode selection and toggle; button restores other elements',
    (tester) async {
      _screen(tester, const Size(320, 640));
      final player = _Player();
      final interactions = PlayerInteractions(
        player: player,
        available: () => true,
        baseSpeed: () => 1,
        onTogglePlayback: () {},
        onFullscreen: () {},
        onEpisode: (_) => '',
      );
      var clean = false;
      var displayedSpeed = 1.0;
      var transitioning = false;
      late StateSetter updateOverlay;
      var episodeTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                updateOverlay = setState;
                return PlayerPortraitOverlay(
                  detail: _detail,
                  index: 0,
                  playing: false,
                  enabled: true,
                  following: false,
                  position: Duration.zero,
                  duration: const Duration(minutes: 2),
                  aspectRatio: 9 / 16,
                  speed: displayedSpeed,
                  interactions: interactions,
                  cleanScreen: clean,
                  transitioning: transitioning,
                  onCleanScreen: () => setState(() => clean = !clean),
                  onBack: () {},
                  onTogglePlayback: () {},
                  onTitle: () {},
                  onSpeed: () {},
                  onMenu: () {},
                  onEpisodes: () => episodeTaps++,
                  onFullscreen: () {},
                  onFavorite: () {},
                  onSeek: (_) {},
                );
              },
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('portrait-danmaku')), findsNothing);
      expect(find.byKey(const ValueKey('player-drama-title')), findsOneWidget);
      expect(find.byTooltip('清屏播放'), findsOneWidget);
      final speed = find.byKey(const ValueKey('portrait-speed'));
      expect(
        find.descendant(of: speed, matching: find.byIcon(Icons.speed_rounded)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: speed, matching: find.text('倍速')),
        findsNothing,
      );
      expect(
        tester.widget<TextButton>(speed).style!.foregroundColor!.resolve({}),
        AppColors.white,
      );
      final bar = tester.getRect(
        find.byKey(const ValueKey('portrait-bottom-bar')),
      );
      final progress = tester.getRect(
        find.byKey(const ValueKey('portrait-progress')),
      );
      final title = tester.getRect(
        find.byKey(const ValueKey('player-drama-title')),
      );
      expect(progress.left, bar.left);
      expect(progress.right, bar.right);
      expect(title.left, bar.left);
      expect(title.right, bar.right);
      updateOverlay(() => displayedSpeed = 1.5);
      await tester.pump();
      expect(
        find.descendant(of: speed, matching: find.text('1.5x')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('portrait-clean-screen')));
      await tester.pumpAndSettle();
      expect(clean, isTrue);
      expect(find.byKey(const ValueKey('player-drama-title')), findsNothing);
      expect(find.byKey(const ValueKey('portrait-progress')), findsNothing);
      expect(find.byKey(const ValueKey('portrait-menu')), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(
        find.byKey(const ValueKey('portrait-clean-screen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('portrait-player-gesture')),
        findsOneWidget,
      );
      await tester.tap(find.textContaining('选集'));
      expect(episodeTaps, 1);
      updateOverlay(() => transitioning = true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('portrait-clean-screen')), findsNothing);
      expect(find.byKey(const ValueKey('player-drama-title')), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      updateOverlay(() => transitioning = false);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(160, 250));
      await tester.pumpAndSettle();
      expect(clean, isTrue);
      await tester.tap(find.byKey(const ValueKey('portrait-clean-screen')));
      await tester.pumpAndSettle();
      expect(clean, isFalse);
      expect(find.byKey(const ValueKey('player-drama-title')), findsOneWidget);
      expect(find.byKey(const ValueKey('portrait-progress')), findsOneWidget);
      expect(find.byKey(const ValueKey('portrait-menu')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      interactions.dispose();
      await player.dispose();
    },
  );
}
