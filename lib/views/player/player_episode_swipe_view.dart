import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:THLRedLook/utils/theme/app_colors.dart';

/// Keeps a single live decoder mounted while two episode pages slide past.
class PlayerEpisodeSwipeView extends StatefulWidget {
  const PlayerEpisodeSwipeView({
    super.key,
    required this.index,
    required this.episodeCount,
    required this.frameReady,
    required this.hasError,
    required this.onSelectEpisode,
    required this.previewBuilder,
    required this.child,
    this.onBack,
    this.onTransitionEnd,
    @visibleForTesting this.captureFrame,
  });

  final int index;
  final int episodeCount;
  final bool frameReady;
  final bool hasError;
  final Future<void> Function(int) onSelectEpisode;
  final Widget Function(int index, bool waiting) previewBuilder;
  final VoidCallback? onBack;
  final VoidCallback? onTransitionEnd;
  final Widget child;
  @visibleForTesting
  final Future<ui.Image?> Function()? captureFrame;

  @override
  State<PlayerEpisodeSwipeView> createState() => PlayerEpisodeSwipeViewState();
}

class PlayerEpisodeSwipeViewState extends State<PlayerEpisodeSwipeView>
    with SingleTickerProviderStateMixin {
  final _frameKey = GlobalKey();
  late final AnimationController _motion = AnimationController(vsync: this)
    ..addListener(_tick);
  Tween<double> _offsetTween = Tween(begin: 0, end: 0);
  ui.Image? _snapshot;
  double _offset = 0;
  double _height = 0;
  int? _target;
  int _fromIndex = 0;
  int _generation = 0;
  bool _dragging = false;
  bool _committing = false;
  bool _switchStarted = false;
  bool _settled = false;
  bool _selectionComplete = false;
  bool _selectionFailed = false;
  Timer? _waitingTimer;
  bool _showWaiting = false;
  bool _revealScheduled = false;

  bool get switching => _committing;
  bool get _active => _dragging || _committing || _motion.isAnimating;
  int get _direction => (_target ?? widget.index) > _fromIndex ? 1 : -1;

  @override
  void didUpdateWidget(PlayerEpisodeSwipeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_active && widget.index != oldWidget.index && widget.index != _target) {
      _reset();
    } else {
      _tryReveal();
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(
      () => _offset = _offsetTween.transform(
        Curves.easeOutCubic.transform(_motion.value),
      ),
    );
  }

  void updateDrag(double offset) {
    if (_height <= 0) return;
    if (_committing) _reset();
    _generation++;
    _motion.stop();
    final next = widget.index + (offset < 0 ? 1 : -1);
    final valid = next >= 0 && next < widget.episodeCount;
    setState(() {
      _fromIndex = widget.index;
      _dragging = true;
      _target = valid ? next : null;
      _offset = (valid ? offset : offset * .18).clamp(-_height, _height);
    });
  }

  void cancelDrag() {
    if (_committing || !_dragging || _height <= 0) return;
    final ticket = ++_generation;
    unawaited(
      _animateTo(0, const Duration(milliseconds: 220)).then((_) {
        if (mounted &&
            ticket == _generation &&
            !_committing &&
            !_motion.isAnimating) {
          setState(_reset);
        }
      }),
    );
  }

  Future<void> _animateTo(double offset, Duration duration) async {
    _offsetTween = Tween(begin: _offset, end: offset);
    _motion.duration = duration;
    try {
      await _motion.forward(from: 0).orCancel;
    } on TickerCanceled {
      // A new gesture or route exit superseded this animation.
    }
  }

  Future<ui.Image?> _captureSnapshot() async {
    try {
      if (widget.captureFrame != null) return await widget.captureFrame!();
      final boundary = _frameKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return null;
      if (boundary.debugNeedsPaint) await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !boundary.attached) return null;
      final Future<ui.Image?> pending = boundary.toImage(
        pixelRatio: math.min(MediaQuery.devicePixelRatioOf(context), 1.5),
      );
      var timedOut = false;
      unawaited(
        pending.then((image) {
          if (timedOut) image?.dispose();
        }, onError: (Object _) {}),
      );
      return await pending.timeout(
        const Duration(milliseconds: 180),
        onTimeout: () {
          timedOut = true;
          return null;
        },
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> switchTo(int index) async {
    if (_committing) _reset();
    if (index < 0 ||
        index >= widget.episodeCount ||
        index == widget.index ||
        _height <= 0) {
      cancelDrag();
      return;
    }
    final ticket = ++_generation;
    _motion.stop();
    setState(() {
      _fromIndex = widget.index;
      _target = index;
      _committing = true;
      _selectionComplete = _selectionFailed = _settled = false;
    });
    final image = await _captureSnapshot();
    if (!mounted || ticket != _generation) {
      image?.dispose();
      return;
    }
    setState(() {
      _snapshot = image;
      _switchStarted = true;
    });
    _waitingTimer?.cancel();
    _waitingTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted &&
          ticket == _generation &&
          _committing &&
          !widget.frameReady) {
        setState(() => _showWaiting = true);
      }
    });
    final slide = _animateTo(
      -_direction * _height,
      const Duration(milliseconds: 280),
    );
    try {
      await widget.onSelectEpisode(index);
    } catch (_) {
      if (mounted && ticket == _generation) _selectionFailed = true;
    } finally {
      if (mounted && ticket == _generation) _selectionComplete = true;
    }
    await slide;
    if (!mounted || ticket != _generation) return;
    _settled = true;
    _tryReveal();
  }

  void _tryReveal() {
    if (!_committing ||
        !_settled ||
        !_selectionComplete ||
        _revealScheduled ||
        (!widget.frameReady && !widget.hasError && !_selectionFailed)) {
      return;
    }
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted || !_committing) return;
      setState(_reset);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _reset() {
    if (_committing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onTransitionEnd?.call();
      });
    }
    _generation++;
    _waitingTimer?.cancel();
    _showWaiting = false;
    _motion.stop();
    final image = _snapshot;
    _snapshot = null;
    if (image != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
    }
    _offset = 0;
    _target = null;
    _dragging = _committing = _switchStarted = _settled = _selectionComplete =
        _selectionFailed = _revealScheduled = false;
  }

  @override
  void dispose() {
    _generation++;
    _waitingTimer?.cancel();
    _motion.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _height = constraints.maxHeight;
      return ClipRect(
        child: ColoredBox(
          color: AppColors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(
                key: const ValueKey('episode-live-page'),
                offset: Offset(
                  0,
                  _switchStarted ? _offset + _direction * _height : _offset,
                ),
                child: AbsorbPointer(
                  absorbing: false,
                  child: RepaintBoundary(key: _frameKey, child: widget.child),
                ),
              ),
              if (_switchStarted)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Transform.translate(
                      key: const ValueKey('episode-outgoing-page'),
                      offset: Offset(0, _offset),
                      child: _snapshot == null
                          ? widget.previewBuilder(_fromIndex, false)
                          : RawImage(image: _snapshot, fit: BoxFit.fill),
                    ),
                  ),
                ),
              if (_active && _target != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Transform.translate(
                      key: const ValueKey('episode-incoming-page'),
                      offset: Offset(0, _offset + _direction * _height),
                      child: AnimatedOpacity(
                        key: const ValueKey('episode-frame-cover'),
                        opacity:
                            _switchStarted &&
                                widget.index == _target &&
                                (widget.frameReady ||
                                    widget.hasError ||
                                    _selectionFailed)
                            ? 0
                            : 1,
                        duration: Duration.zero,
                        child: widget.previewBuilder(_target!, _showWaiting),
                      ),
                    ),
                  ),
                ),
              if (_committing && widget.onBack != null)
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    child: IconButton(
                      tooltip: '退出播放',
                      onPressed: widget.onBack,
                      color: AppColors.white,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
