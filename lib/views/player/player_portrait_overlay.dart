import 'package:THLRedLook/views/player/player_clean_screen_icon.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:THLRedLook/core/player/player_interactions.dart';
import 'package:THLRedLook/models/catalog/models.dart';
import 'package:THLRedLook/utils/theme/app_colors.dart';
import 'package:THLRedLook/views/player/player_controls_view.dart';

class PlayerPortraitOverlay extends StatelessWidget {
  const PlayerPortraitOverlay({
    super.key,
    required this.detail,
    required this.index,
    required this.playing,
    required this.enabled,
    required this.following,
    required this.position,
    required this.duration,
    required this.aspectRatio,
    required this.speed,
    required this.interactions,
    required this.onBack,
    required this.onTogglePlayback,
    required this.onTitle,
    required this.onSpeed,
    required this.onMenu,
    required this.onEpisodes,
    required this.onFullscreen,
    required this.onFavorite,
    required this.onSeek,
    required this.cleanScreen,
    required this.onCleanScreen,
    this.onDownload,
    this.textScale = 1,
    this.fillScreen = false,
    this.transitioning = false,
    this.onToggleFit,
  });
  final bool fillScreen;
  final bool transitioning;
  final VoidCallback? onToggleFit;
  final DramaDetail detail;
  final int index;
  final bool playing, enabled, following, cleanScreen;
  final Duration position, duration;
  final double aspectRatio, speed, textScale;
  final PlayerInteractions interactions;
  final VoidCallback onBack,
      onTogglePlayback,
      onTitle,
      onSpeed,
      onMenu,
      onEpisodes,
      onFullscreen,
      onFavorite,
      onCleanScreen;
  final VoidCallback? onDownload;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(
        MediaQuery.textScalerOf(context).scale(1) * textScale,
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        final footerHeight = compact ? 240.0 : 260.0;
        final videoHeight = math.min(
          constraints.maxHeight,
          constraints.maxWidth / (aspectRatio > 0 ? aspectRatio : 9 / 16),
        );
        final progress = duration.inMilliseconds <= 0
            ? 0.0
            : (position.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              );
        final episode = detail.episodes[index];
        final status =
            detail.drama.releaseStatus.isNotEmpty &&
                detail.drama.releaseStatus != 'unknown'
            ? detail.drama.releaseLabel
            : '';
        return Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              key: const ValueKey('portrait-player-gesture'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => interactions.pointerDown(
                event,
                swipeEnabled: true,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
              onPointerMove: interactions.pointerMove,
              onPointerUp: interactions.pointerUp,
              onPointerCancel: interactions.pointerCancel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: enabled
                    ? () {
                        if (!interactions.suppressTap) onTogglePlayback();
                      }
                    : null,
                onDoubleTap: enabled ? onTogglePlayback : null,
                child: Center(
                  child: !playing && enabled
                      ? const Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.white,
                          size: 68,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            if (!cleanScreen) ...[
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.black,
                        AppColors.transparent,
                        AppColors.transparent,
                        AppColors.black,
                      ],
                      stops: [0, .18, .65, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 4,
                right: 4,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '返回',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      Expanded(
                        child: Text(
                          '第${episode.number}集',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('portrait-menu'),
                        tooltip: '播放菜单',
                        onPressed: onMenu,
                        icon: const Icon(Icons.more_vert_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              if (aspectRatio > 1)
                Positioned(
                  top: ((constraints.maxHeight + videoHeight) / 2 + 8).clamp(
                    80,
                    math.max(80, constraints.maxHeight - footerHeight - 52),
                  ),
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FilledButton.tonalIcon(
                      onPressed: onFullscreen,
                      icon: const Icon(
                        Icons.screen_rotation_alt_rounded,
                        size: 18,
                      ),
                      label: const Text('全屏观看'),
                    ),
                  ),
                ),
            ],
            if (!cleanScreen || (!playing && !transitioning))
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!cleanScreen) ...[
                        InkWell(
                          key: const ValueKey('player-drama-title'),
                          onTap: onTitle,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    detail.drama.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 3,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 10,
                            ),
                          ),
                          child: Slider(
                            key: const ValueKey('portrait-progress'),
                            padding: EdgeInsets.zero,
                            value: progress,
                            onChanged: enabled && duration > Duration.zero
                                ? onSeek
                                : null,
                            semanticFormatterCallback: (_) =>
                                '播放进度 ${(progress * 100).round()}%',
                          ),
                        ),
                      ],
                      Row(
                        key: const ValueKey('portrait-bottom-bar'),
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: onEpisodes,
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '选集${status.isEmpty ? '' : ' · $status'} · 全${detail.episodes.length}集',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.expand_less_rounded),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('portrait-display-mode'),
                            tooltip: fillScreen ? '适应屏幕' : '撑满屏幕',
                            onPressed: onToggleFit,
                            icon: Icon(
                              fillScreen
                                  ? Icons.fit_screen_rounded
                                  : Icons.aspect_ratio_rounded,
                            ),
                          ),
                          TextButton(
                            key: const ValueKey('portrait-speed'),
                            onPressed: onSpeed,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.white,
                            ),
                            child: speed == 1
                                ? const Icon(
                                    Icons.speed_rounded,
                                    semanticLabel: '倍速',
                                  )
                                : Text('${speed}x'),
                          ),
                          IconButton(
                            key: const ValueKey('portrait-clean-screen'),
                            tooltip: cleanScreen ? '退出清屏' : '清屏播放',
                            onPressed: onCleanScreen,
                            icon: PlayerCleanScreenIcon(active: cleanScreen),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            if (!cleanScreen)
              PlayerGestureHudOverlay(interactions: interactions),
            AnimatedBuilder(
              animation: interactions,
              builder: (_, _) => interactions.feedback.isEmpty
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: const Alignment(0, -.65),
                      child: IgnorePointer(
                        child: Text(
                          interactions.feedback,
                          style: const TextStyle(
                            color: Colors.white,
                            backgroundColor: Colors.black54,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );
}
