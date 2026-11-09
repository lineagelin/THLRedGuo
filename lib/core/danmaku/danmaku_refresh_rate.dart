import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Each overlay owns a request so disposing an outgoing player cannot release
/// the incoming player's request during an episode/page transition.
class DanmakuRefreshRate {
  static const _channel = MethodChannel('duanju/device');
  static int _nextOwner = 0;
  final String _owner = 'danmaku-${_nextOwner++}';
  bool _enabled = false;

  void setEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    unawaited(_send(enabled));
  }

  Future<void> _send(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setDanmakuHighRefreshRate', {
        'owner': _owner,
        'enabled': enabled,
      });
    } on PlatformException {
      // A rejected refresh-rate hint must not interrupt video playback.
    } on MissingPluginException {
      // Other platforms and older native hosts keep the system default.
    }
  }

  void dispose() => setEnabled(false);
}
