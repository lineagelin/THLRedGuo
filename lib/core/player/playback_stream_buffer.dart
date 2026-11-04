import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:THLRedLook/models/catalog/models.dart';

/// Retains a bounded MP4 prefix and its index at the end of the file. The
/// decoder reads these exact bytes locally; uncached ranges stream upstream.
/// Encrypted bytes stay encrypted, with the original key passed to the player.
class PlaybackStreamBuffer {
  static const prefixLimit = 2 * 1024 * 1024;
  static const suffixLimit = 256 * 1024;

  final _client = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 4);
  HttpServer? _server;
  PlaybackPlan? _source;
  Uint8List _prefix = Uint8List(0), _suffix = Uint8List(0);
  int _length = 0;
  bool _closed = false;
  String _path = '';

  Future<HttpClientResponse> _request(int start, int end) async {
    final request = await _client.getUrl(Uri.parse(_source!.url));
    for (final header in _source!.headers.entries) {
      request.headers.set(header.key, header.value);
    }
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
    return request.close().timeout(const Duration(seconds: 8));
  }

  bool _matches(HttpClientResponse response, int start, int end) =>
      response.statusCode == HttpStatus.partialContent &&
      response.headers.value(HttpHeaders.contentRangeHeader) ==
          'bytes $start-$end/$_length';

  Future<Uint8List> _read(HttpClientResponse response, int expected) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 4))) {
      if (_closed || bytes.length + chunk.length > expected) {
        throw const HttpException('预加载响应超出范围');
      }
      bytes.add(chunk);
    }
    if (bytes.length != expected) {
      throw const HttpException('预加载响应不完整');
    }
    return bytes.takeBytes();
  }

  Future<PlaybackPlan> open(PlaybackPlan plan) async {
    _source = plan;
    final uri = Uri.tryParse(plan.url);
    if (plan.local ||
        uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.path.toLowerCase().endsWith('.m3u8')) {
      return plan;
    }
    try {
      final response = await _request(0, prefixLimit - 1);
      final range = RegExp(r'^bytes 0-(\d+)/(\d+)$').firstMatch(
        response.headers.value(HttpHeaders.contentRangeHeader) ?? '',
      );
      if (response.statusCode != HttpStatus.partialContent || range == null) {
        throw const HttpException('视频不支持分段预加载');
      }
      _length = int.parse(range[2]!);
      final end = int.parse(range[1]!);
      if (_length <= 0 || end != min(prefixLimit, _length) - 1) {
        throw const HttpException('预加载范围无效');
      }
      _prefix = await _read(response, end + 1);
      // Do not proxy playlists or other non-MP4 responses under an MP4 URL.
      if (_prefix.length < 12 ||
          String.fromCharCodes(_prefix.sublist(4, 8)) != 'ftyp') {
        throw const HttpException('非 MP4 视频直接播放');
      }
      if (_prefix.length < _length) {
        final start = max(_prefix.length, _length - suffixLimit);
        try {
          final tail = await _request(start, _length - 1);
          if (!_matches(tail, start, _length - 1)) {
            throw const HttpException('视频索引预加载失败');
          }
          _suffix = await _read(tail, _length - start);
        } catch (_) {
          // The prefix is still usable; the decoder can fetch the index.
        }
      }
      if (_closed) throw StateError('预加载已取消');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      if (_closed) {
        await server.close(force: true);
        throw StateError('预加载已取消');
      }
      _server = server;
      server.autoCompress = false;
      final random = Random.secure();
      _path =
          '/${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}/media.mp4';
      server.listen(
        (request) => unawaited(_serve(request)),
        onError: (Object _) {},
      );
      return PlaybackPlan(
        url: 'http://127.0.0.1:${server.port}$_path',
        decryptionKey: plan.decryptionKey,
        mediaBytes: _length,
        quality: plan.quality,
        qualities: plan.qualities,
        session: plan.session,
        danmakuId: plan.danmakuId,
        prefetchedBytes: _prefix.length + _suffix.length,
        expiresAt: plan.expiresAt,
        routeIndex: plan.routeIndex,
        routeCount: plan.routeCount,
      );
    } catch (_) {
      await close();
      return plan;
    }
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    // Player cancellation may close the socket while a range is streaming.
    unawaited(response.done.catchError((Object _) {}));
    try {
      if (_closed ||
          request.uri.path != _path ||
          request.connectionInfo?.remoteAddress.isLoopback != true) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      if (!{'GET', 'HEAD'}.contains(request.method)) {
        response.statusCode = HttpStatus.methodNotAllowed;
        await response.close();
        return;
      }
      var start = 0, end = _length - 1;
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
        if (match == null || (match[1]!.isEmpty && match[2]!.isEmpty)) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */$_length',
          );
          await response.close();
          return;
        }
        if (match[1]!.isEmpty) {
          start = max(0, _length - int.parse(match[2]!));
        } else {
          start = int.parse(match[1]!);
          if (match[2]!.isNotEmpty) end = min(end, int.parse(match[2]!));
        }
        if (start > end || start >= _length) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */$_length',
          );
          await response.close();
          return;
        }
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$_length',
        );
      }
      response.headers.contentType = ContentType('video', 'mp4');
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.contentLength = end - start + 1;
      if (request.method != 'HEAD') {
        var cursor = start;
        final suffixStart = _length - _suffix.length;
        while (cursor <= end && !_closed) {
          if (cursor < _prefix.length) {
            final stop = min(end + 1, _prefix.length);
            response.add(Uint8List.sublistView(_prefix, cursor, stop));
            cursor = stop;
          } else if (_suffix.isNotEmpty && cursor >= suffixStart) {
            response.add(
              Uint8List.sublistView(
                _suffix,
                cursor - suffixStart,
                end + 1 - suffixStart,
              ),
            );
            cursor = end + 1;
          } else {
            final stop = _suffix.isEmpty ? end : min(end, suffixStart - 1);
            await response.flush();
            final upstream = await _request(cursor, stop);
            if (!_matches(upstream, cursor, stop)) {
              throw const HttpException('视频分段响应无效');
            }
            await response.addStream(
              upstream.timeout(const Duration(seconds: 15)),
            );
            cursor = stop + 1;
          }
        }
      }
      await response.close();
    } catch (_) {
      try {
        (await response.detachSocket()).destroy();
      } catch (_) {}
    }
  }

  Future<void> close() async {
    _closed = true;
    _client.close(force: true);
    await _server?.close(force: true);
    _server = null;
    _prefix = _suffix = Uint8List(0);
  }
}
