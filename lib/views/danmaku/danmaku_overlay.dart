import 'dart:math' as math;
import 'package:THLRedLook/views/danmaku/douyin_emoji_text.dart';

import 'package:flutter/material.dart';

import 'package:THLRedLook/utils/theme/app_colors.dart';
import 'package:THLRedLook/core/danmaku/danmaku_controller.dart';
import 'package:THLRedLook/core/danmaku/danmaku_refresh_rate.dart';
import 'package:THLRedLook/models/danmaku/danmaku_models.dart';

class DanmakuFlight {
  const DanmakuFlight(
    this.item,
    this.text,
    this.lane,
    this.width,
    this.durationMs,
  );
  final DanmakuItem item;
  final String text;
  final int lane;
  final double width;
  final int durationMs;
}

int calculateDanmakuLifetimeMs(DanmakuItem item) {
  final hash = item.id.hashCode.abs();
  final factor = (hash % 1000) / 1000.0;
  final offset = ((factor - 0.5) * 3000).round();
  return (8000 + offset).clamp(6500, 9800);
}

List<DanmakuFlight> planDanmaku(
  List<DanmakuItem> items, {
  required double width,
  required int rows,
  required double Function(String) measure,
  double speedScale = 1.0,
  int mergeSeconds = 5,
  Iterable<String> blockedWords = const [],
}) {
  if (!width.isFinite || width <= 0 || rows < 1) return const [];
  final laneCount = rows.clamp(1, 8);
  final lanes = List<DanmakuFlight?>.filled(laneCount, null);
  final sorted = items.toList()..sort((a, b) => a.timeMs.compareTo(b.timeMs));
  final seen = <String>{};
  final lastDisplayed = <String, int>{};
  final mergeMs = mergeSeconds.clamp(2, 10) * 1000;
  final flights = <DanmakuFlight>[];
  final speed = speedScale.isFinite ? speedScale.clamp(0.6, 1.5) : 1.0;
  final filters = blockedWords
      .map((word) => word.trim().toLowerCase())
      .where((word) => word.isNotEmpty)
      .toList();

  for (final item in sorted) {
    if (item.id.isEmpty ||
        item.text.trim().isEmpty ||
        item.timeMs < 0 ||
        !seen.add(item.id) ||
        filters.any((word) => item.text.toLowerCase().contains(word))) {
      continue;
    }
    final content = item.text.trim();
    final previousTime = lastDisplayed[content];
    if (previousTime != null && item.timeMs - previousTime <= mergeMs) {
      continue;
    }
    if (flights.reversed
            .takeWhile(
              (flight) => item.timeMs - flight.item.timeMs < flight.durationMs,
            )
            .length >=
        40) {
      continue;
    }
    final runes = item.text.runes;
    final text =
        String.fromCharCodes(runes.take(100)) + (runes.length > 100 ? '…' : '');
    final size = measure(text).ceilToDouble() + 8;
    final durationMs = (calculateDanmakuLifetimeMs(item) / speed).round();

    int bestLane = -1;
    double maxSafetyMargin = -1;

    for (int l = 0; l < laneCount; l++) {
      final prev = lanes[l];
      if (prev == null) {
        bestLane = l;
        break;
      }
      final gap = item.timeMs - prev.item.timeMs;
      if (gap >= prev.durationMs) {
        bestLane = l;
        break;
      }

      // 条件 1: 入场碰撞检查（后弹幕入场时，前弹幕尾部已完全进入且拉开至少 28px）
      final prevSpeed = (width + prev.width) / prev.durationMs;
      final prevMovedAtEntry = prevSpeed * gap;
      final entryClearance = prevMovedAtEntry - prev.width;
      if (entryClearance < 28) {
        continue;
      }

      // 条件 2: 出场追尾检查（在前弹幕出屏幕前，后弹幕不能追上前弹幕尾部）
      final currSpeed = (width + size) / durationMs;
      final remainingTime = prev.durationMs - gap;
      final currMovedAtPrevExit = currSpeed * remainingTime;
      final exitClearance = width - currMovedAtPrevExit;
      if (exitClearance < 28) {
        continue;
      }

      final safetyMargin = math.min(entryClearance, exitClearance);
      if (safetyMargin > maxSafetyMargin) {
        maxSafetyMargin = safetyMargin;
        bestLane = l;
      }
    }

    if (bestLane < 0) continue;

    final flight = DanmakuFlight(item, text, bestLane, size, durationMs);
    lanes[bestLane] = flight;
    flights.add(flight);
    lastDisplayed[content] = item.timeMs;
  }
  return flights;
}

class DanmakuOverlay extends StatefulWidget {
  const DanmakuOverlay({
    super.key,
    required this.controller,
    required this.aspectRatio,
    this.style = const DanmakuStyle(),
  });
  final DanmakuController controller;
  final double aspectRatio;
  final DanmakuStyle style;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with WidgetsBindingObserver {
  Object? _layout;
  Object? _measurementLayout;
  final _measurements = <String, double>{};
  List<DanmakuFlight> _schedule = const [];
  final _refreshRate = DanmakuRefreshRate();
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_syncRefreshRate);
    _syncRefreshRate();
  }

  @override
  void didUpdateWidget(DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncRefreshRate);
      widget.controller.addListener(_syncRefreshRate);
    }
    _syncRefreshRate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncRefreshRate();
  }

  void _syncRefreshRate() => _refreshRate.setEnabled(
    _resumed && widget.style.highRefreshRate && widget.controller.moving,
  );

  @override
  void dispose() {
    widget.controller.removeListener(_syncRefreshRate);
    WidgetsBinding.instance.removeObserver(this);
    _refreshRate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!constraints.hasBoundedWidth ||
                !constraints.hasBoundedHeight ||
                constraints.maxWidth <= 0 ||
                constraints.maxHeight <= 0) {
              return const SizedBox.shrink();
            }
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final baseFontSize = width < 600 ? 16.0 : 20.0;
            final fontSize = baseFontSize * widget.style.fontSizeScale;
            final scaler = MediaQuery.textScalerOf(context);
            final rowHeight = scaler.scale(fontSize) * 1.5;
            final availableRows = ((height - 8) / rowHeight).floor().clamp(
              0,
              4,
            );
            final rows = math.min(widget.style.rows.clamp(1, 4), availableRows);
            final opacity = widget.style.opacity.clamp(0.1, 1.0);
            final style = TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.white.withValues(alpha: opacity),
              height: 1.2,
              shadows: widget.style.shadowEnabled
                  ? [
                      Shadow(
                        color: AppColors.black.withValues(
                          alpha: opacity * 0.85,
                        ),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ]
                  : null,
            );
            return Center(
              child: SizedBox(
                width: width,
                height: height,
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: widget.controller,
                    builder: (context, _) {
                      final controller = widget.controller;
                      final positionMs = controller.motionPositionMs;
                      if (!controller.visible || rows == 0) {
                        return const SizedBox.shrink();
                      }
                      final layout = (
                        controller,
                        controller.dataRevision,
                        width,
                        rows,
                        fontSize,
                        scaler,
                        widget.style,
                      );
                      if (_layout != layout) {
                        _layout = layout;
                        final measurementLayout = (style, scaler);
                        if (_measurementLayout != measurementLayout) {
                          _measurementLayout = measurementLayout;
                          _measurements.clear();
                        }
                        final measuredTexts = <String>{};
                        _schedule = planDanmaku(
                          controller.items,
                          width: width,
                          rows: rows,
                          speedScale: widget.style.speedScale,
                          mergeSeconds: widget.style.mergeSeconds,
                          blockedWords: widget.style.blockedWordsEnabled
                              ? widget.style.blockedWords
                              : const [],
                          measure: (text) {
                            measuredTexts.add(text);
                            return _measurements.putIfAbsent(
                              text,
                              () =>
                                  measureDanmakuEmojiText(text, style, scaler),
                            );
                          },
                        );
                        _measurements.removeWhere(
                          (text, _) => !measuredTexts.contains(text),
                        );
                      }
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final flight in _schedule)
                            if (positionMs >= flight.item.timeMs &&
                                positionMs <
                                    flight.item.timeMs + flight.durationMs)
                              Positioned(
                                key: ValueKey('danmaku-item-${flight.item.id}'),
                                left: 0,
                                top: 8 + flight.lane * rowHeight,
                                width: flight.width,
                                height: rowHeight,
                                child: _DanmakuMotion(
                                  flight: flight,
                                  width: width,
                                  positionMs: positionMs,
                                  moving: controller.moving,
                                  rate: controller.rate,
                                  revision: controller.motionRevision,
                                  style: style,
                                  scaler: scaler,
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _DanmakuMotion extends StatefulWidget {
  const _DanmakuMotion({
    required this.flight,
    required this.width,
    required this.positionMs,
    required this.moving,
    required this.rate,
    required this.revision,
    required this.style,
    required this.scaler,
  });
  final DanmakuFlight flight;
  final double width;
  final int positionMs;
  final bool moving;
  final double rate;
  final int revision;
  final TextStyle style;
  final TextScaler scaler;

  @override
  State<_DanmakuMotion> createState() => _DanmakuMotionState();
}

class _DanmakuMotionState extends State<_DanmakuMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this);
  Widget? _label;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_DanmakuMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.width != widget.width ||
        oldWidget.flight.width != widget.flight.width ||
        oldWidget.flight.item.timeMs != widget.flight.item.timeMs ||
        oldWidget.flight.durationMs != widget.flight.durationMs) {
      _sync();
    } else if (oldWidget.moving != widget.moving ||
        oldWidget.rate != widget.rate) {
      _sync(preservePosition: true);
    }
    if (oldWidget.style != widget.style ||
        oldWidget.scaler != widget.scaler ||
        oldWidget.flight.text != widget.flight.text) {
      _label = null;
    }
  }

  void _sync({bool preservePosition = false}) {
    _motion.stop();
    final lifetime = widget.flight.durationMs;
    final elapsed = preservePosition
        ? _motion.value * lifetime
        : (widget.positionMs - widget.flight.item.timeMs).clamp(0, lifetime);
    _motion.value = elapsed / lifetime;
    if (widget.moving && elapsed < lifetime) {
      _motion.animateTo(
        1,
        duration: Duration(
          microseconds: ((lifetime - elapsed) * 1000 / widget.rate)
              .round()
              .clamp(1, 86400000000),
        ),
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    child: _label ??= RepaintBoundary(
      child: DouyinEmojiText(
        text: widget.flight.text,
        style: widget.style,
        scaler: widget.scaler,
      ),
    ),
    builder: (context, child) => Transform.translate(
      key: ValueKey('danmaku-motion-${widget.flight.item.id}'),
      offset: Offset(
        widget.width - (widget.width + widget.flight.width) * _motion.value,
        0,
      ),
      child: child,
    ),
  );
}
