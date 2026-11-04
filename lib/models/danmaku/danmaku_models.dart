import 'package:flutter/widgets.dart' show StringCharacters;

const danmakuWindowMs = 30000;
const danmakuLifetimeMs = 8000;
const danmakuMaxDurationMs = 86400000;
const danmakuFontScales = [0.8, 0.9, 1.0, 1.25, 1.5];
const danmakuFontLabels = ['小', '较小', '适中', '较大', '大'];
const danmakuSpeedScales = [0.6, 0.8, 1.0, 1.25, 1.5];
const danmakuSpeedLabels = ['慢', '较慢', '适中', '较快', '快'];
const danmakuMaxBlockedWords = 30;
const danmakuMaxWordLength = 10;

int _nearestStep(double value, List<double> options) {
  var nearest = 0;
  for (var index = 1; index < options.length; index++) {
    if ((options[index] - value).abs() < (options[nearest] - value).abs()) {
      nearest = index;
    }
  }
  return nearest;
}

List<String> normalizeDanmakuBlockedWords(Iterable<String> words) {
  final result = <String>[];
  final seen = <String>{};
  for (final word in words) {
    final cleaned = word
        .trim()
        .characters
        .take(danmakuMaxWordLength)
        .toString();
    if (cleaned.isEmpty || !seen.add(cleaned.toLowerCase())) continue;
    result.add(cleaned);
    if (result.length == danmakuMaxBlockedWords) break;
  }
  return List.unmodifiable(result);
}

class DanmakuItem {
  const DanmakuItem({
    required this.id,
    required this.text,
    required this.timeMs,
  });
  final String id;
  final String text;
  final int timeMs;
}

class DanmakuPage {
  const DanmakuPage({
    required this.episodeId,
    required this.startMs,
    required this.nextMs,
    required this.items,
  });
  final String episodeId;
  final int startMs;
  final int nextMs;
  final List<DanmakuItem> items;

  factory DanmakuPage.fromJson(
    Map<String, dynamic> json, {
    required String episodeId,
    required int startMs,
    required int durationMs,
  }) {
    final next = json['nextMs'];
    final rows = json['items'];
    if (json['episodeId'] != episodeId ||
        json['startMs'] != startMs ||
        next is! int ||
        next <= startMs ||
        next > durationMs ||
        rows is! List) {
      throw const FormatException('弹幕分集或时间范围不符');
    }
    final items = <DanmakuItem>[];
    final seen = <String>{};
    for (final row in rows.take(90)) {
      if (row is! Map) continue;
      final id = row['id'], text = row['text'], time = row['timeMs'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 120 ||
          text is! String ||
          time is! int ||
          time < startMs ||
          time >= next ||
          seen.contains(id)) {
        continue;
      }
      final cleaned = text
          .replaceAll(RegExp(r'[\x00-\x1f\x7f-\x9f\u2028\u2029]'), ' ')
          .trim();
      if (cleaned.isEmpty) continue;
      seen.add(id);
      items.add(
        DanmakuItem(
          id: id,
          text: String.fromCharCodes(cleaned.runes.take(181)),
          timeMs: time,
        ),
      );
    }
    items.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return DanmakuPage(
      episodeId: episodeId,
      startMs: startMs,
      nextMs: next,
      items: List.unmodifiable(items),
    );
  }
}

class DanmakuStyle {
  const DanmakuStyle({
    this.fontSizeScale = 1.0,
    this.opacity = 1.0,
    this.displayArea = 0.5,
    this.speedScale = 1.0,
    this.rows = 3,
    this.mergeSeconds = 5,
    this.shadowEnabled = true,
    this.blockedWordsEnabled = true,
    this.blockedWords = const [],
  });

  final double fontSizeScale;
  final double opacity;
  final double displayArea;
  final double speedScale;
  final int rows;
  final int mergeSeconds;
  final bool shadowEnabled;
  final bool blockedWordsEnabled;
  final List<String> blockedWords;

  int get fontSizeStep => _nearestStep(fontSizeScale, danmakuFontScales);
  int get speedStep => _nearestStep(speedScale, danmakuSpeedScales);
  String get fontSizeLabel => danmakuFontLabels[fontSizeStep];
  String get speedLabel => danmakuSpeedLabels[speedStep];

  DanmakuStyle copyWith({
    double? fontSizeScale,
    double? opacity,
    double? displayArea,
    double? speedScale,
    int? rows,
    int? mergeSeconds,
    bool? shadowEnabled,
    bool? blockedWordsEnabled,
    List<String>? blockedWords,
  }) => DanmakuStyle(
    fontSizeScale: fontSizeScale ?? this.fontSizeScale,
    opacity: opacity ?? this.opacity,
    displayArea: displayArea ?? this.displayArea,
    speedScale: speedScale ?? this.speedScale,
    rows: rows ?? this.rows,
    mergeSeconds: (mergeSeconds ?? this.mergeSeconds).clamp(2, 10),
    shadowEnabled: shadowEnabled ?? this.shadowEnabled,
    blockedWordsEnabled: blockedWordsEnabled ?? this.blockedWordsEnabled,
    blockedWords: blockedWords == null
        ? this.blockedWords
        : normalizeDanmakuBlockedWords(blockedWords),
  );

  Map<String, dynamic> toJson() => {
    'fontSizeScale': fontSizeScale,
    'opacity': opacity,
    'displayArea': displayArea,
    'speedScale': speedScale,
    'rows': rows,
    'mergeSeconds': mergeSeconds,
    'shadowEnabled': shadowEnabled,
    'blockedWordsEnabled': blockedWordsEnabled,
    'blockedWords': blockedWords,
  };

  factory DanmakuStyle.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DanmakuStyle();
    double number(String key, double fallback) {
      final value = json[key];
      return value is num && value.isFinite ? value.toDouble() : fallback;
    }

    final font = number('fontSizeScale', 1.0);
    final op = number('opacity', 1.0);
    final area = number('displayArea', 0.5);
    final speed = number('speedScale', 1.0);
    final words = json['blockedWords'];
    return DanmakuStyle(
      fontSizeScale: danmakuFontScales[_nearestStep(font, danmakuFontScales)],
      opacity: op.clamp(0.1, 1.0),
      displayArea: area.clamp(0.2, 1.0),
      speedScale: danmakuSpeedScales[_nearestStep(speed, danmakuSpeedScales)],
      rows: number('rows', 3).clamp(1, 4).round(),
      mergeSeconds: number('mergeSeconds', 5).clamp(2, 10).round(),
      shadowEnabled: json['shadowEnabled'] is bool
          ? json['shadowEnabled'] as bool
          : true,
      blockedWordsEnabled: json['blockedWordsEnabled'] is bool
          ? json['blockedWordsEnabled'] as bool
          : true,
      blockedWords: normalizeDanmakuBlockedWords(
        words is List ? words.whereType<String>() : const [],
      ),
    );
  }
}
