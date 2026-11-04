import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:THLRedLook/core/player/playback_preferences.dart';
import 'package:THLRedLook/models/danmaku/danmaku_models.dart';
import 'package:THLRedLook/utils/theme/app_colors.dart';
import 'package:THLRedLook/utils/theme/app_theme.dart';
import 'package:THLRedLook/views/danmaku/danmaku_overlay.dart';
import 'package:THLRedLook/views/player/player_danmaku_sheet_view.dart';

const _capture = bool.fromEnvironment('DANMAKU_SCREENSHOTS');
final _previewKey = GlobalKey();

Future<void> _capturePreview(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final boundary =
        _previewKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/danmaku-checks')
      ..createSync(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void _screen(WidgetTester tester, [Size size = const Size(390, 844)]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _openSettings(
  WidgetTester tester, {
  DanmakuStyle style = const DanmakuStyle(),
  Future<void> Function(DanmakuStyle)? save,
  bool dark = false,
}) async {
  var theme = dark ? AppTheme.dark : AppTheme.light;
  if (_capture) {
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'PreviewChinese'),
    );
  }
  await tester.pumpWidget(
    RepaintBoundary(
      key: _previewKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          backgroundColor: AppColors.playerSceneDark,
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => PlayerDanmakuSheetView.show(
                  context: context,
                  enabled: true,
                  style: style,
                  onEnabledChanged: (_) async {},
                  onStyleChanged: save ?? (_) async {},
                ),
                child: const Text('打开设置'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开设置'));
  await tester.pumpAndSettle();
}

Future<void> _openWords(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('danmaku-blocked-words-settings')),
  );
  await tester.tap(
    find.byKey(const ValueKey('danmaku-blocked-words-settings')),
  );
  await tester.pumpAndSettle();
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
      final flutterRoot =
          Platform.environment['FLUTTER_ROOT'] ?? 'D:/Program Files/flutter';
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await icons.load();
    }
  });

  test('old settings migrate and opacity never falls below ten percent', () {
    final style = DanmakuStyle.fromJson({
      'opacity': 0,
      'fontSizeScale': .8,
      'displayArea': 1,
    });
    expect(style.opacity, .1);
    expect(style.fontSizeLabel, '小');
    expect(style.speedLabel, '适中');
    expect(style.rows, 3);
    expect(style.mergeSeconds, 5);
    expect(style.shadowEnabled, isTrue);
    expect(DanmakuStyle.fromJson({'mergeSeconds': -1}).mergeSeconds, 2);
    expect(DanmakuStyle.fromJson({'mergeSeconds': 99}).mergeSeconds, 10);
    expect(DanmakuStyle.fromJson({'mergeSeconds': double.nan}).mergeSeconds, 5);
    expect(DanmakuStyle.fromJson({'opacity': -1}).opacity, .1);
    expect(DanmakuStyle.fromJson({'opacity': 2}).opacity, 1);
    expect(DanmakuStyle.fromJson({'opacity': double.nan, 'rows': 99}).rows, 4);
  });

  test('all settings survive playback preference serialization', () {
    final original = PlaybackPreferences(
      danmakuStyle: const DanmakuStyle().copyWith(
        opacity: .1,
        fontSizeScale: .9,
        speedScale: 1.5,
        rows: 4,
        mergeSeconds: 8,
        shadowEnabled: false,
        blockedWordsEnabled: false,
        blockedWords: ['6', '剧透'],
      ),
    );
    final restored = PlaybackPreferences.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(restored.danmakuStyle.toJson(), original.danmakuStyle.toJson());
  });

  test(
    'blocked words are trimmed, unique and limited by user-perceived characters',
    () {
      final words = normalizeDanmakuBlockedWords([
        ' ',
        ' VIP ',
        'vip',
        '6',
        '👨‍👩‍👧‍👦' * 11,
      ]);
      expect(words.take(3), ['VIP', '6', '👨‍👩‍👧‍👦' * 10]);
      expect(
        normalizeDanmakuBlockedWords(
          List.generate(40, (index) => '词$index'),
        ).length,
        30,
      );
      expect(() => words.add('new'), throwsUnsupportedError);
    },
  );

  test('merge uses full content and an inclusive configurable time window', () {
    final items = [
      const DanmakuItem(id: 'a', text: '重复[送花]', timeMs: 0),
      const DanmakuItem(id: 'b', text: '重复[送花]', timeMs: 1000),
      const DanmakuItem(id: 'c', text: '重复[送花]', timeMs: 5000),
      const DanmakuItem(id: 'd', text: '重复[送花]', timeMs: 5001),
      const DanmakuItem(id: 'e', text: '重复[送花]', timeMs: 15002),
    ];
    List<String> ids(int seconds) => planDanmaku(
      items.reversed.toList(),
      width: 360,
      rows: 8,
      measure: (_) => 40,
      mergeSeconds: seconds,
    ).map((f) => f.item.id).toList();
    expect(ids(5), ['a', 'd', 'e']);
    expect(ids(2), ['a', 'c', 'e']);
    expect(ids(10), ['a', 'e']);
    final prefix = '好' * 110;
    expect(
      planDanmaku(
        [
          DanmakuItem(id: 'one', text: '$prefix甲', timeMs: 0),
          DanmakuItem(id: 'two', text: '$prefix乙', timeMs: 100),
        ],
        width: 360,
        rows: 2,
        measure: (_) => 40,
      ).length,
      2,
    );
  });

  test('filter matches substrings in the full comment before truncation', () {
    final texts = ['666', '真6啊', 'VIP来了', '${'好' * 110}剧透', '正常弹幕'];
    final flights = planDanmaku(
      [
        for (var i = 0; i < texts.length; i++)
          DanmakuItem(id: '$i', text: texts[i], timeMs: i * 20000),
      ],
      width: 360,
      rows: 4,
      measure: (text) => text.length * 10,
      blockedWords: ['6', 'vip', '剧透'],
    );
    expect(flights.map((flight) => flight.text), ['正常弹幕']);
    expect(
      planDanmaku(
        [const DanmakuItem(id: '1', text: '666', timeMs: 0)],
        width: 360,
        rows: 1,
        measure: (_) => 30,
      ).length,
      1,
    );
  });

  test(
    'speed changes travel time and scheduling respects row count without overlaps',
    () {
      final items = List.generate(
        30,
        (i) => DanmakuItem(id: '$i', text: '弹幕$i', timeMs: i * 700),
      );
      int lifetime(double speed) => planDanmaku(
        [items.first],
        width: 360,
        rows: 1,
        measure: (_) => 60,
        speedScale: speed,
      ).single.durationMs;
      expect(lifetime(.6), greaterThan(lifetime(1)));
      expect(lifetime(1.5), lessThan(lifetime(1)));
      for (final rows in [1, 2, 3, 4]) {
        for (final speed in danmakuSpeedScales) {
          final flights = planDanmaku(
            items,
            width: 360,
            rows: rows,
            measure: (_) => 60,
            speedScale: speed,
          );
          expect(
            flights.every((flight) => flight.lane >= 0 && flight.lane < rows),
            isTrue,
          );
          for (var time = 0; time < 40000; time += 100) {
            for (var lane = 0; lane < rows; lane++) {
              final active = flights
                  .where(
                    (f) =>
                        f.lane == lane &&
                        time >= f.item.timeMs &&
                        time < f.item.timeMs + f.durationMs,
                  )
                  .toList();
              final rects = active.map((f) {
                final x =
                    360 -
                    (360 + f.width) * (time - f.item.timeMs) / f.durationMs;
                return Rect.fromLTWH(x, 0, f.width, 20);
              }).toList()..sort((a, b) => a.left.compareTo(b.left));
              for (var i = 1; i < rects.length; i++) {
                expect(rects[i - 1].right, lessThanOrEqualTo(rects[i].left));
              }
            }
          }
        }
      }
    },
  );

  testWidgets(
    'five sliders expose required steps and save ten percent on drag',
    (tester) async {
      _screen(tester);
      DanmakuStyle? saved;
      await _openSettings(tester, save: (value) async => saved = value);
      expect(find.byType(Slider), findsNWidgets(5));
      expect(find.text('显示弹幕'), findsNothing);
      final merge = tester.widget<Slider>(
        find.byKey(const ValueKey('danmaku-merge-slider')),
      );
      expect(
        (merge.min, merge.max, merge.divisions, merge.value),
        (2.0, 10.0, 8, 5.0),
      );
      final opacity = tester.widget<Slider>(
        find.byKey(const ValueKey('danmaku-opacity-slider')),
      );
      expect((opacity.min, opacity.max, opacity.divisions), (.1, 1.0, 90));
      for (final id in ['font-size', 'speed']) {
        final slider = tester.widget<Slider>(
          find.byKey(ValueKey('danmaku-$id-slider')),
        );
        expect((slider.min, slider.max, slider.divisions), (0.0, 4.0, 4));
      }
      expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('danmaku-rows-slider')))
            .divisions,
        3,
      );
      await _capturePreview(tester, 'settings-light');
      await tester.drag(
        find.byKey(const ValueKey('danmaku-opacity-slider')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(saved!.opacity, .1);
      expect(find.text('10%'), findsOneWidget);
    },
  );

  testWidgets('shadow toggle persists and reset restores the default shadow', (
    tester,
  ) async {
    _screen(tester);
    DanmakuStyle? saved;
    await _openSettings(tester, save: (value) async => saved = value);
    final toggle = find.byKey(const ValueKey('danmaku-shadow-switch'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(saved!.shadowEnabled, isFalse);
    expect(DanmakuStyle.fromJson(saved!.toJson()).shadowEnabled, isFalse);
    await tester.tap(find.byKey(const ValueKey('danmaku-reset')));
    await tester.pumpAndSettle();
    expect(saved!.shadowEnabled, isTrue);
  });

  testWidgets('reset restores sliders and preserves blocked words', (
    tester,
  ) async {
    _screen(tester);
    DanmakuStyle? saved;
    await _openSettings(
      tester,
      style: const DanmakuStyle(
        opacity: .1,
        fontSizeScale: 1.5,
        speedScale: 1.5,
        rows: 1,
        blockedWords: ['剧透'],
      ),
      save: (value) async => saved = value,
    );
    await tester.tap(find.byKey(const ValueKey('danmaku-reset')));
    await tester.pumpAndSettle();
    expect(
      (saved!.opacity, saved!.fontSizeScale, saved!.speedScale, saved!.rows),
      (1.0, 1.0, 1.0, 3),
    );
    expect(saved!.blockedWords, ['剧透']);
  });

  testWidgets('blocked words add, reject duplicates, toggle and delete', (
    tester,
  ) async {
    _screen(tester);
    var saved = const DanmakuStyle();
    await _openSettings(tester, save: (value) async => saved = value);
    await _openWords(tester);
    await _capturePreview(tester, 'blocked-words-empty');
    await tester.tap(find.byKey(const ValueKey('danmaku-add-blocked-word')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('danmaku-confirm-word')));
    await tester.pumpAndSettle();
    expect(find.text('请输入屏蔽词'), findsOneWidget);
    await tester.enterText(find.byType(TextField), ' 6 ');
    await tester.tap(find.byKey(const ValueKey('danmaku-confirm-word')));
    await tester.pumpAndSettle();
    expect(saved.blockedWords, ['6']);
    expect(find.text('添加屏蔽词（1/30）'), findsOneWidget);
    await _capturePreview(tester, 'blocked-words-list');
    await tester.tap(find.byKey(const ValueKey('danmaku-add-blocked-word')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '6');
    await tester.tap(find.byKey(const ValueKey('danmaku-confirm-word')));
    await tester.pumpAndSettle();
    expect(find.text('该屏蔽词已存在'), findsOneWidget);
    await tester.tap(find.byTooltip('取消添加'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('danmaku-blocked-words-switch')),
    );
    await tester.pumpAndSettle();
    expect(saved.blockedWordsEnabled, isFalse);
    expect(saved.blockedWords, ['6']);
    await tester.tap(find.byKey(const ValueKey('danmaku-delete-word-6')));
    await tester.pumpAndSettle();
    expect(saved.blockedWords, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'word limit disables adding and save failure restores previous state',
    (tester) async {
      _screen(tester);
      await _openSettings(
        tester,
        style: DanmakuStyle(blockedWords: List.generate(30, (i) => '词$i')),
        save: (_) async => throw StateError('storage full'),
      );
      await _openWords(tester);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('danmaku-add-blocked-word')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('danmaku-delete-word-词0')));
      await tester.pumpAndSettle();
      expect(find.text('未能保存屏蔽词，请重试。'), findsOneWidget);
      expect(find.text('词0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 640), const Size(740, 360)]) {
    testWidgets('settings and text input fit $size including keyboard', (
      tester,
    ) async {
      _screen(tester, size);
      await _openSettings(tester, dark: true);
      expect(tester.takeException(), isNull);
      if (size.width == 320) await _capturePreview(tester, 'settings-dark');
      await _openWords(tester);
      await tester.tap(find.byKey(const ValueKey('danmaku-add-blocked-word')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height > 400 ? 300 : 220,
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), '一二三四五六七八九十十一');
      await tester.tap(find.byKey(const ValueKey('danmaku-confirm-word')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
