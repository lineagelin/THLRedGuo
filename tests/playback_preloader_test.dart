import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:THLRedLook/core/bridge/core_bridge.dart';
import 'package:THLRedLook/core/player/playback_preloader.dart';
import 'package:THLRedLook/core/player/playback_stream_buffer.dart';
import 'package:THLRedLook/models/catalog/models.dart';

class _Origin {
  final bytes = Uint8List.fromList(
    List.generate(3 * 1024 * 1024, (index) => index % 251),
  )..setRange(4, 8, 'ftyp'.codeUnits);
  late HttpServer server;
  int requests = 0;
  bool ranges = true;

  String get url => 'http://127.0.0.1:${server.port}/video.mp4';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      final response = request.response;
      try {
        if (request.headers.value('X-Test') != 'media-token') {
          response.statusCode = 403;
          await response.close();
          return;
        }
        final range = request.headers.value('Range');
        var start = 0, end = bytes.length - 1;
        if (ranges && range != null) {
          final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
          start = int.parse(match[1]!);
          end = min(end, int.parse(match[2]!));
          response.statusCode = 206;
          response.headers.set(
            'Content-Range',
            'bytes $start-$end/${bytes.length}',
          );
        }
        response.contentLength = end - start + 1;
        response.add(Uint8List.sublistView(bytes, start, end + 1));
        await response.close();
      } catch (_) {
        // Cancelling speculative reads may disconnect before the origin finishes.
      }
    });
  }
}

class _Repository extends AppRepository {
  _Repository(this.plan);
  final PlaybackPlan plan;
  int calls = 0;
  final released = <String>[];
  Completer<PlaybackPlan?>? pending;
  @override
  Future<PlaybackPlan?> preload(
    Drama drama,
    Episode episode, {
    int quality = 0,
    bool online = false,
  }) async {
    calls++;
    return pending == null ? plan : pending!.future;
  }

  @override
  Future<void> release(String session) async => released.add(session);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _ready(PlaybackPreloader preloader) async {
  final done = Completer<void>();
  void changed() {
    if (!preloader.loading && !done.isCompleted) done.complete();
  }

  // prepare uses a short delay before marking itself as loading.
  await Future<void>.delayed(const Duration(milliseconds: 60));
  if (!preloader.loading) return;
  preloader.addListener(changed);
  try {
    await done.future.timeout(const Duration(seconds: 5));
  } finally {
    preloader.removeListener(changed);
  }
}

void main() {
  late _Origin origin;
  late PlaybackPlan source;
  setUp(() async {
    origin = _Origin();
    await origin.start();
    source = PlaybackPlan(
      url: origin.url,
      headers: const {'X-Test': 'media-token'},
      decryptionKey: '00112233445566778899aabbccddeeff',
      quality: 1080,
      qualities: const [1080, 720],
      session: 'next-session',
      danmakuId: 'next-comments',
      routeCount: 2,
    );
  });
  tearDown(() async => origin.server.close(force: true));

  test(
    'window caches two episodes in each direction and reuses overlapping entries',
    () async {
      final repo = _Repository(const PlaybackPlan(url: 'file:///cached.mp4'));
      final cache = PlaybackPreloader(repo);
      addTearDown(cache.dispose);
      final drama = Drama(
        id: 'hongguo:window',
        source: 'hongguo',
        title: 'Window',
      );
      final episodes = [
        for (var n = 1; n <= 6; n++) Episode({'id': '$n'}, n),
      ];
      cache.prepareWindow(drama, episodes, 2);
      await _ready(cache);
      expect(repo.calls, 4);
      expect(cache.take(drama, episodes[3]), isNotNull);
      cache.prepareWindow(drama, episodes, 3);
      await _ready(cache);
      expect(repo.calls, 6);
      expect(cache.take(drama, episodes[1]), isNotNull);
      expect(cache.take(drama, episodes[4]), isNotNull);
    },
  );

  test(
    'feed selection preserves the cached target while shifting the neighbor window',
    () async {
      final repo = _Repository(const PlaybackPlan(url: 'file:///cached.mp4'));
      final cache = PlaybackPreloader(repo);
      addTearDown(cache.dispose);
      final first = Drama(
        id: 'hongguo:first',
        source: 'hongguo',
        title: 'First',
      );
      final second = Drama(
        id: 'hongguo:second',
        source: 'hongguo',
        title: 'Second',
      );
      final ep = Episode({'id': '1'}, 1);
      cache.prepareTargets([(second, ep)]);
      await _ready(cache);
      cache.prepareTargets([(first, ep)], current: (second, ep));
      expect(cache.take(second, ep), isNotNull);
      await _ready(cache);
      expect(repo.calls, 2);
    },
  );

  test('preloads during the current episode, including unknown duration', () {
    expect(
      PlaybackPreloader.shouldPrepare(
        duration: const Duration(minutes: 5),
        position: const Duration(seconds: 1),
      ),
      isTrue,
    );
    expect(
      PlaybackPreloader.shouldPrepare(
        duration: Duration.zero,
        position: const Duration(seconds: 2),
      ),
      isTrue,
    );
    expect(
      PlaybackPreloader.shouldPrepare(
        duration: const Duration(minutes: 5),
        position: Duration.zero,
      ),
      isFalse,
    );
    expect(
      PlaybackPreloader.shouldPrepare(
        duration: const Duration(seconds: 1),
        position: const Duration(seconds: 1),
      ),
      isFalse,
    );
  });

  test(
    'cached startup and tail are served without another origin request',
    () async {
      final buffer = PlaybackStreamBuffer();
      addTearDown(buffer.close);
      final plan = await buffer.open(source);
      expect(plan.url, isNot(source.url));
      expect(
        plan.prefetchedBytes,
        PlaybackStreamBuffer.prefixLimit + PlaybackStreamBuffer.suffixLimit,
      );
      expect(plan.decryptionKey, source.decryptionKey);
      expect(plan.session, source.session);
      expect(plan.danmakuId, source.danmakuId);
      expect(plan.qualities, source.qualities);
      expect(plan.offline, isFalse);
      final count = origin.requests;
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      for (final range in ['bytes=0-65535', 'bytes=-8192']) {
        final request = await client.getUrl(Uri.parse(plan.url));
        request.headers.set('Range', range);
        final response = await request.close();
        expect(response.statusCode, 206);
        final bytes = await response.fold<List<int>>(
          [],
          (a, b) => a..addAll(b),
        );
        expect(
          bytes,
          range.endsWith('65535')
              ? origin.bytes.sublist(0, 65536)
              : origin.bytes.sublist(origin.bytes.length - 8192),
        );
      }
      expect(origin.requests, count);
    },
  );

  test(
    'full reads combine cached bytes with the uncached middle exactly',
    () async {
      final buffer = PlaybackStreamBuffer();
      addTearDown(buffer.close);
      final plan = await buffer.open(source);
      final count = origin.requests;
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final response = await (await client.getUrl(Uri.parse(plan.url))).close();
      final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
      expect(bytes, origin.bytes);
      expect(origin.requests, count + 1);
      final invalid = await client.getUrl(Uri.parse(plan.url));
      invalid.headers.set('Range', 'bytes=${origin.bytes.length}-');
      final rejected = await invalid.close();
      expect(rejected.statusCode, 416);
      await rejected.drain<void>();
      final head = await (await client.headUrl(Uri.parse(plan.url))).close();
      expect(head.contentLength, origin.bytes.length);
      await head.drain<void>();
      expect(origin.requests, count + 1);
    },
  );

  test('unsupported ranges fall back to the original playable URL', () async {
    origin.ranges = false;
    final buffer = PlaybackStreamBuffer();
    addTearDown(buffer.close);
    expect(await buffer.open(source), same(source));
  });

  test('consumed cache survives clear until its playback retires', () async {
    final repository = _Repository(source);
    final preloader = PlaybackPreloader(repository);
    addTearDown(preloader.dispose);
    final drama = Drama(id: 'hongguo:1', source: 'hongguo', title: 'Test');
    final episode = Episode({'id': '2'}, 2);
    preloader.prepare(drama, episode);
    preloader.prepare(drama, episode);
    await _ready(preloader);
    expect(repository.calls, 1);
    final cached = preloader.take(drama, episode)!;
    preloader.clear();
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final request = await client.getUrl(Uri.parse(cached.url));
    request.headers.set('Range', 'bytes=0-15');
    final response = await request.close();
    expect(
      await response.fold<List<int>>([], (a, b) => a..addAll(b)),
      origin.bytes.sublist(0, 16),
    );
    expect(preloader.take(drama, Episode({'id': '3'}, 3)), isNull);
    await preloader.releaseRetired();
    expect(repository.released, isEmpty);
  });

  test(
    'switching episode discards and releases a stale in-flight preload',
    () async {
      final repository = _Repository(source)
        ..pending = Completer<PlaybackPlan?>();
      final preloader = PlaybackPreloader(repository);
      addTearDown(preloader.dispose);
      final drama = Drama(id: 'hongguo:1', source: 'hongguo', title: 'Test');
      preloader.prepare(drama, Episode({'id': '2'}, 2));
      await Future<void>.delayed(const Duration(milliseconds: 70));
      preloader.clear();
      repository.pending!.complete(source);
      await Future<void>.delayed(Duration.zero);
      expect(repository.released, ['next-session']);
      expect(preloader.take(drama, Episode({'id': '2'}, 2)), isNull);
    },
  );
}
