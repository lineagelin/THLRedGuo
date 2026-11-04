import 'package:THLRedLook/core/store/local_snapshot.dart';
import 'package:THLRedLook/views/common/widgets.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:THLRedLook/core/bridge/core_bridge.dart';
import 'package:THLRedLook/core/js/js_source_service.dart';
import 'package:THLRedLook/core/store/local_store.dart';
import 'package:THLRedLook/core/store/saved_library.dart';
import 'package:THLRedLook/models/catalog/models.dart';
import 'package:THLRedLook/pages/account/my_page.dart';
import 'package:THLRedLook/pages/account/account_page.dart';
import 'package:THLRedLook/pages/downloads/downloads_page.dart';
import 'package:THLRedLook/pages/home/home_page.dart';
import 'package:THLRedLook/utils/theme/app_theme.dart';

final _dramas = [
  for (var n = 1; n <= 5; n++)
    Drama(id: 'hongguo:$n', source: 'hongguo', title: '测试短剧$n', episodes: 10),
];

class _Repository extends AppRepository {
  bool failDownloads = false;
  @override
  bool get supportsDownloads => true;
  @override
  Future<List<DownloadJob>> downloads() async {
    if (failDownloads) throw Exception('offline');
    return [
      for (var n = 0; n < _dramas.length; n++)
        DownloadJob(
          id: 'job$n',
          drama: _dramas[n],
          episode: Episode({'id': 'ep$n'}, 1),
          state: 'completed',
          created: n + 1,
        ),
    ];
  }

  @override
  Future<CatalogPage> catalog(
    String source, {
    int page = 1,
    String query = '',
    String category = '',
    bool force = false,
  }) async => CatalogPage([]);
  @override
  Future<CatalogPage> cached(String source, {String category = ''}) async =>
      CatalogPage([]);
  @override
  Future<String> cover(Drama drama, {bool force = false}) async => '';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<LocalStore> _store() async {
  JsSourceService.current = null;
  SharedPreferences.setMockInitialValues({
    'keepScreenOn': false,
    'favorites': jsonEncode(_dramas.map((drama) => drama.toJson()).toList()),
    'history': jsonEncode([
      for (var n = 0; n < _dramas.length; n++)
        WatchEntry(
          drama: _dramas[n],
          episode: n + 1,
          position: 20,
          duration: 120,
          updatedAt: DateTime(2026, 11, 1, 0, n),
        ).toJson(),
    ]),
    'private_sources_set': ['hongguo'],
    'privacy_vault_entries': 'legacy private library data',
    'sourceGateEnabled': true,
    'sourceGateOff': false,
    'sourceGateSalt': 'a' * 32,
    'sourceGateHash': 'b' * 64,
  });
  return LocalStore(await SharedPreferences.getInstance());
}

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  const capture = bool.fromEnvironment('MY_PAGE_SCREENSHOTS');
  setUpAll(() async {
    if (!capture) return;
    for (final family in ['PreviewChinese', 'Hiragino Sans GB']) {
      await (FontLoader(family)..addFont(
            File(
              'C:/Windows/Fonts/msyh.ttc',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
    await (FontLoader('MaterialIcons')..addFont(
          File(
            'D:/Program Files/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });

  test(
    'upgrading a saved fixed-column layout preserves library access',
    () async {
      final store = await _store();
      await store.setDisplayMode('standard');
      final prefs = await SharedPreferences.getInstance();
      final snapshot =
          jsonDecode(prefs.getString(LocalSnapshot.storageKey)!)
              as Map<String, dynamic>;
      (snapshot['values'] as Map)['discoveryColumns'] = '2';
      await prefs.setString(LocalSnapshot.storageKey, jsonEncode(snapshot));
      store.dispose();
      final restored = LocalStore(prefs);
      expect(restored.locked, isFalse);
      expect(restored.history, hasLength(5));
      expect(restored.displayMode, 'standard');
      restored.dispose();
    },
  );

  testWidgets(
    'discovery adapts columns while respecting the larger minimum covers',
    (tester) async {
      late BuildContext gridContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              gridContext = context;
              return const SizedBox();
            },
          ),
        ),
      );
      if (!gridContext.mounted) return;
      final counts = <int>[];
      for (final width in [288.0, 358.0, 568.0, 720.0, 1120.0]) {
        final minimum = width < 600 ? 120.0 : 196.0;
        final delegate =
            dramaGridDelegate(gridContext, width, minimumTileWidth: minimum)
                as SliverGridDelegateWithFixedCrossAxisCount;
        final cover =
            (width -
                (delegate.crossAxisCount - 1) * delegate.crossAxisSpacing) /
            delegate.crossAxisCount;
        expect(cover, greaterThanOrEqualTo(minimum));
        counts.add(delegate.crossAxisCount);
      }
      expect(counts, [2, 2, 4, 3, 5]);
    },
  );

  testWidgets(
    'legacy private source flags no longer hide records or restrict sources',
    (tester) async {
      final store = await _store();
      expect(store.locked, false);
      expect(store.allowsSource('hongguo'), true);
      expect(store.history, hasLength(5));
      expect(store.currentHistory, hasLength(5));
      expect(store.watched('hongguo:5'), isNotNull);
      expect(store.favorites, hasLength(5));
      expect(
        store.preferences.getString('privacy_vault_entries'),
        'legacy private library data',
      );
      store.dispose();
    },
  );

  testWidgets(
    'My previews latest three and opens full libraries without branded app bar',
    (tester) async {
      _size(tester, const Size(390, 1100));
      final store = await _store();
      final repo = _Repository();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: capture
              ? AppTheme.light.copyWith(
                  textTheme: AppTheme.light.textTheme.apply(
                    fontFamily: 'PreviewChinese',
                  ),
                )
              : AppTheme.light,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: MyPage(
                repository: repo,
                store: store,
                onSwitchSource: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('my-official-account')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('my-official-account')));
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.byKey(const Key('hongguo-account-login')), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      for (final section in ['favorites', 'history', 'downloads']) {
        expect(find.byKey(ValueKey('my-$section-hongguo:5')), findsOneWidget);
        expect(find.byKey(ValueKey('my-$section-hongguo:3')), findsOneWidget);
        expect(find.byKey(ValueKey('my-$section-hongguo:2')), findsNothing);
      }
      if (capture) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/my-page-checks').createSync(recursive: true);
          await File(
            'build/my-page-checks/my-page.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.byKey(const ValueKey('my-all-favorites')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SavedLibrary>(find.byType(SavedLibrary)).allSources,
        true,
      );
      expect(find.text('我的追剧 · 5'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byTooltip('隐私短剧库'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('my-all-history')));
      await tester.tap(find.byKey(const ValueKey('my-all-history')));
      await tester.pumpAndSettle();
      expect(find.text('最近观看 · 5'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('my-all-downloads')),
      );
      await tester.tap(find.byKey(const ValueKey('my-all-downloads')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<DownloadsScreen>(find.byType(DownloadsScreen)).allSources,
        true,
      );
      expect(find.text('下载任务'), findsOneWidget);
      expect(find.byTooltip('设置'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'bottom navigation contains discovery, recommendations and My; source switch lives in My',
    (tester) async {
      _size(tester, const Size(390, 844));
      final store = await _store();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(repository: _Repository(), store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('source-switch')), findsNothing);
      expect(find.text('发现'), findsNWidgets(2));
      expect(find.text('追剧'), findsNothing);
      expect(find.text('最近观看'), findsNothing);
      expect(find.text('下载'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
      await tester.pumpAndSettle();
      expect(find.byType(MyPage), findsOneWidget);
      expect(find.byKey(const ValueKey('my-source-switch')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('my-source-switch')));
      await tester.pumpAndSettle();
      expect(find.text('切换数据源'), findsOneWidget);
      expect(find.byTooltip('隐私数据源设置'), findsNothing);
      expect(find.byTooltip('站源密码与管理'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'download preview failure can retry without losing other sections',
    (tester) async {
      _size(tester, const Size(390, 1100));
      final store = await _store();
      final repo = _Repository()..failDownloads = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MyPage(
              repository: repo,
              store: store,
              onSwitchSource: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('重试'));
      expect(find.text('下载记录暂时无法读取'), findsOneWidget);
      repo.failDownloads = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('下载记录暂时无法读取'), findsNothing);
      expect(
        find.byKey(const ValueKey('my-downloads-hongguo:5')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
