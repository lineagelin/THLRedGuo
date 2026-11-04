import 'dart:async';
import 'package:flutter/foundation.dart';

class PlaybackSleepTimer extends ChangeNotifier {
  PlaybackSleepTimer({required this.onExpire, DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final VoidCallback onExpire;
  final DateTime Function() _now;
  DateTime? deadline;
  Timer? _timer;
  String get label => deadline == null
      ? '未开启'
      : '${(deadline!.difference(_now()).inMilliseconds.clamp(0, 86400000) / 60000).ceil()}分钟后停止';

  void setDuration(Duration? duration) {
    _timer?.cancel();
    deadline = duration == null ? null : _now().add(duration);
    if (duration != null) _timer = Timer(duration, checkDeadline);
    notifyListeners();
  }

  void checkDeadline() {
    if (deadline == null || _now().isBefore(deadline!)) return;
    _timer?.cancel();
    deadline = null;
    notifyListeners();
    onExpire();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
