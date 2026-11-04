import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:THLRedLook/core/bridge/core_bridge.dart';
import 'package:THLRedLook/models/catalog/models.dart';
import 'package:THLRedLook/core/player/playback_stream_buffer.dart';
import 'package:THLRedLook/utils/diary/diary_service.dart';

class _CachedEpisode {
  _CachedEpisode(this.plan, this.buffer, this.expires);
  final PlaybackPlan plan;
  final PlaybackStreamBuffer buffer;
  final DateTime expires;
  bool used = false, released = false;
}

class PlaybackPreloader extends ChangeNotifier {
  PlaybackPreloader(this.repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final AppRepository repository;
  final DateTime Function() _now;
  final _cache = <String, _CachedEpisode>{};
  final _wanted = <String, (Drama, Episode, int, bool)>{};
  final _retry = <String, DateTime>{};
  final _retired = <_CachedEpisode>[];
  _CachedEpisode? _active;
  PlaybackStreamBuffer? _warming;
  bool _closed = false, _pumping = false, _paused = false;
  int _revision = 0;
  String? _protectedKey;
  String error = '';
  bool get loading => _pumping;
  String get status => _cache.isNotEmpty
      ? '已缓存附近 ${_cache.length} 个视频'
      : loading
      ? '正在缓存附近视频'
      : error.isEmpty
      ? '提前缓存前后各两集'
      : '预加载暂不可用，切集时会重新获取';
  static bool shouldPrepare({
    required Duration duration,
    required Duration position,
    double rate = 1,
  }) =>
      position >= const Duration(seconds: 1) &&
      (duration <= Duration.zero || position < duration);
  String _key(Drama drama, Episode episode, int quality, bool online) =>
      '${drama.id}\u0000${episode.number}\u0000$quality\u0000$online';
  void prepare(
    Drama drama,
    Episode episode, {
    int quality = 0,
    bool online = false,
  }) => prepareTargets([(drama, episode)], quality: quality, online: online);
  void prepareWindow(
    Drama drama,
    List<Episode> episodes,
    int index, {
    int quality = 0,
  }) => prepareTargets([
    for (final delta in [1, -1, 2, -2])
      if (index + delta >= 0 && index + delta < episodes.length)
        (drama, episodes[index + delta]),
  ], quality: quality);
  void prepareTargets(
    List<(Drama, Episode)> targets, {
    int quality = 0,
    bool online = false,
    (Drama, Episode)? current,
  }) {
    if (_closed) return;
    _protectedKey = current == null
        ? null
        : _key(current.$1, current.$2, quality, online);
    _paused = false;
    _wanted.clear();
    for (final target in targets.take(4)) {
      _wanted[_key(target.$1, target.$2, quality, online)] = (
        target.$1,
        target.$2,
        quality,
        online,
      );
    }
    for (final key in _cache.keys.toList()) {
      final entry = _cache[key]!;
      if (((!_wanted.containsKey(key) && key != _protectedKey) ||
              !_now().isBefore(entry.expires)) &&
          !identical(entry, _active)) {
        _cache.remove(key);
        if (!identical(entry, _active)) _release(entry);
      }
    }
    if (!_pumping) unawaited(_pump());
  }

  // Source lookups run serially so speculative requests cannot cancel each other.
  Future<void> _pump() async {
    _pumping = true;
    notifyListeners();
    try {
      while (!_closed && !_paused) {
        final key = _wanted.keys
            .where(
              (key) =>
                  !_cache.containsKey(key) &&
                  !_now().isBefore(_retry[key] ?? DateTime(2000)),
            )
            .firstOrNull;
        if (key == null) break;
        final target = _wanted[key]!;
        final revision = _revision;
        PlaybackPlan? source;
        PlaybackStreamBuffer? buffer;
        try {
          source = await repository.preload(
            target.$1,
            target.$2,
            quality: target.$3,
            online: target.$4,
          );
          if (source == null || source.url.isEmpty) {
            throw AppFailure('未取得预加载结果');
          }
          if (_closed || revision != _revision || !_wanted.containsKey(key)) {
            await repository.release(source.session);
            continue;
          }
          var expires = _now().add(const Duration(minutes: 5));
          if (source.expiresAt > 0) {
            final limit = DateTime.fromMillisecondsSinceEpoch(
              source.expiresAt,
            ).subtract(const Duration(seconds: 5));
            if (limit.isBefore(expires)) expires = limit;
          }
          if (!expires.isAfter(_now())) throw AppFailure('播放凭证即将过期');
          buffer = PlaybackStreamBuffer();
          _warming = buffer;
          final plan = await buffer.open(source);
          if (identical(_warming, buffer)) _warming = null;
          if (_closed || revision != _revision || !_wanted.containsKey(key)) {
            await buffer.close();
            await repository.release(source.session);
            continue;
          }
          _cache[key] = _CachedEpisode(plan, buffer, expires);
          error = '';
          DiaryService.add(
            '[Preload] 附近视频已缓存: 剧=${target.$1.cleanSourceId}, 集=${target.$2.number}, 缓存=${plan.prefetchedBytes} bytes',
          );
        } catch (failure) {
          await buffer?.close();
          if (source != null) await repository.release(source.session);
          if (revision == _revision) {
            error = failure.toString();
            _retry[key] = _now().add(const Duration(seconds: 15));
          }
        }
      }
    } finally {
      _pumping = false;
      if (!_closed) notifyListeners();
    }
  }

  PlaybackPlan? take(
    Drama drama,
    Episode episode, {
    int quality = 0,
    bool online = false,
  }) {
    final entry = _cache[_key(drama, episode, quality, online)];
    final result = entry != null && _now().isBefore(entry.expires)
        ? entry
        : null;
    final previous = _active;
    _active = result;
    if (previous != null && !identical(previous, result)) {
      _retired.add(previous);
    }
    if (result != null) {
      result.used = true;
      DiaryService.add(
        '[Preload] 切集复用: 剧=${drama.cleanSourceId}, 集=${episode.number}, 缓存=${result.plan.prefetchedBytes} bytes',
      );
    }
    return result?.plan;
  }

  void pause() {
    _paused = true;
  }

  void _release(_CachedEpisode entry) {
    if (entry.released) return;
    entry.released = true;
    unawaited(entry.buffer.close());
    if (!entry.used) {
      unawaited(
        repository.release(entry.plan.session).catchError((Object _) {}),
      );
    }
  }

  void clear() {
    _revision++;
    _wanted.clear();
    _protectedKey = null;
    _retry.clear();
    _paused = true;
    if (_pumping) {
      unawaited(repository.cancelPreload().catchError((Object _) {}));
    }
    unawaited(_warming?.close());
    _warming = null;
    for (final entry in _cache.values) {
      if (!identical(entry, _active)) _release(entry);
    }
    _cache.clear();
    error = '';
    if (!_closed) notifyListeners();
  }

  Future<void> releaseRetired() async {
    for (final key in _cache.keys.toList()) {
      final entry = _cache[key]!;
      if (!_wanted.containsKey(key) &&
          key != _protectedKey &&
          !identical(entry, _active)) {
        _cache.remove(key);
        _release(entry);
      }
    }
    for (final entry in _retired.toSet()) {
      if (!identical(entry, _active) && !_cache.containsValue(entry)) {
        _release(entry);
      }
    }
    _retired.clear();
  }

  @override
  void dispose() {
    _closed = true;
    clear();
    if (_active != null) _release(_active!);
    _active = null;
    unawaited(releaseRetired());
    super.dispose();
  }
}
