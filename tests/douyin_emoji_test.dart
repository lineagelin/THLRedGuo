import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:THLRedLook/models/danmaku/douyin_emoji_assets.dart';
import 'package:THLRedLook/views/danmaku/douyin_emoji_text.dart';

void main() {
  test(
    'known tags use bundled pictures and unknown tags preserve their text',
    () {
      final parts = splitDanmakuEmoji('好看[送花][捂脸][尚不存在]赞');
      expect(parts.map((p) => p.text).join(), '好看[送花][捂脸][尚不存在]赞');
      expect(parts.where((p) => p.asset != null).length, 2);
      expect(parts.last.text, '[尚不存在]赞');
      for (final path in douyinEmojiAssets.values.toSet()) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    },
  );
  testWidgets(
    'emoji width scales with font and opacity follows danmaku setting',
    (tester) async {
      const style = TextStyle(fontSize: 20, color: Color(0x80FFFFFF));
      final width = measureDanmakuEmojiText(
        '[送花][捂脸]',
        style,
        TextScaler.linear(1.2),
      );
      expect(width, 60);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DouyinEmojiText(
              text: '赞[送花][捂脸]',
              style: style,
              scaler: TextScaler.noScaling,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(2));
      expect(
        tester.widgetList<Opacity>(find.byType(Opacity)).map((p) => p.opacity),
        everyElement(closeTo(128 / 255, .001)),
      );
    },
  );
}
