import 'package:flutter/material.dart';
import 'package:THLRedLook/models/danmaku/douyin_emoji_assets.dart';

class DanmakuTextPart {
  const DanmakuTextPart(this.text, [this.asset]);
  final String text;
  final String? asset;
}

List<DanmakuTextPart> splitDanmakuEmoji(String text) {
  final parts = <DanmakuTextPart>[];
  var start = 0;
  for (final match in RegExp(r'\[[^\[\]\r\n]{1,40}\]').allMatches(text)) {
    final token = match.group(0)!;
    final asset = douyinEmojiAssets[token];
    if (asset == null) continue;
    if (match.start > start) {
      parts.add(DanmakuTextPart(text.substring(start, match.start)));
    }
    parts.add(DanmakuTextPart(token, asset));
    start = match.end;
  }
  if (start < text.length) parts.add(DanmakuTextPart(text.substring(start)));
  return parts;
}

double measureDanmakuEmojiText(
  String text,
  TextStyle style,
  TextScaler scaler,
) {
  var width = 0.0;
  final side = scaler.scale(style.fontSize ?? 16) * 1.25;
  for (final part in splitDanmakuEmoji(text)) {
    if (part.asset != null) {
      width += side;
      continue;
    }
    final painter = TextPainter(
      text: TextSpan(text: part.text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    width += painter.width;
    painter.dispose();
  }
  return width;
}

class DouyinEmojiText extends StatelessWidget {
  const DouyinEmojiText({
    super.key,
    required this.text,
    required this.style,
    required this.scaler,
  });
  final String text;
  final TextStyle style;
  final TextScaler scaler;
  @override
  Widget build(BuildContext context) {
    final side = scaler.scale(style.fontSize ?? 16) * 1.25;
    Widget plain(String value) => Text(
      value,
      style: style,
      textScaler: scaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      softWrap: false,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        for (final part in splitDanmakuEmoji(text))
          if (part.asset == null)
            plain(part.text)
          else
            Opacity(
              opacity: style.color?.a ?? 1,
              child: Image.asset(
                part.asset!,
                width: side,
                height: side,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => plain(part.text),
              ),
            ),
      ],
    );
  }
}
