import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:THLRedLook/core/series/hongguo_series.dart';
import 'package:THLRedLook/models/catalog/models.dart';
import 'package:THLRedLook/utils/theme/app_theme.dart';
import 'package:THLRedLook/views/player/player_episodes_sheet_view.dart';

const _capture = bool.fromEnvironment('PLAYER_LAYOUT_SCREENSHOTS');
final _preview = GlobalKey();
Future<void> _snapshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final boundary =
        _preview.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/player-redesign').createSync(recursive: true);
    await File(
      'build/player-redesign/episode-drawer-$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
    'drawer groups fifty episodes and preserves indices and real series data',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      if (_capture) {
        await tester.runAsync(() async {
          final font = FontLoader('PreviewChinese')
            ..addFont(
              File(
                'C:/Windows/Fonts/msyh.ttc',
              ).readAsBytes().then(ByteData.sublistView),
            );
          await font.load();
        });
      }
      final episodes = [
        for (var i = 1; i <= 103; i++)
          Episode({'id': '$i', 'currentEpisode': i}, i),
      ];
      const drama = Drama(
        id: 'one',
        source: 'hongguo',
        title: '真实剧名',
        description: '接口简介',
        tags: ['都市'],
      );
      const other = Drama(
        id: 'two',
        source: 'hongguo',
        title: '真实第二季',
        heat: '123万',
      );
      int? picked;
      Drama? season;
      await tester.pumpWidget(
        RepaintBoundary(
          key: _preview,
          child: MaterialApp(
            theme: _capture
                ? AppTheme.dark.copyWith(
                    textTheme: AppTheme.dark.textTheme.apply(
                      fontFamily: 'PreviewChinese',
                    ),
                  )
                : AppTheme.dark,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: PlayerEpisodesSheetView(
                  episodes: episodes,
                  currentIndex: 49,
                  drama: drama,
                  currentDramaId: drama.id,
                  onEpisodeSelected: (index) => picked = index,
                  seriesEntries: const [
                    HongguoSeriesEntry(drama: other, season: 2, unit: '季'),
                  ],
                  onSeasonSelected: (value) => season = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _snapshot(tester, 'episodes');
      expect(find.text('1-50'), findsOneWidget);
      expect(find.text('51-100'), findsOneWidget);
      expect(find.text('101-103'), findsOneWidget);
      expect(find.byKey(const ValueKey('sheet-episode-50')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sheet-episode-50')));
      expect(picked, 49);
      await tester.tap(find.byKey(const ValueKey('episode-group-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet-episode-51')));
      expect(picked, 50);
      await tester.tap(find.byKey(const ValueKey('episode-group-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet-episode-103')));
      expect(picked, 102);
      await tester.tap(find.text('简介'));
      await tester.pumpAndSettle();
      expect(find.text('接口简介'), findsOneWidget);
      await _snapshot(tester, 'intro');
      await tester.tap(find.text('系列剧'));
      await tester.pumpAndSettle();
      expect(find.text('真实第二季'), findsOneWidget);
      await _snapshot(tester, 'series');
      await tester.tap(find.text('播放'));
      expect(season?.id, 'two');
      expect(tester.takeException(), isNull);
    },
  );
}
