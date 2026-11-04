import 'package:flutter/material.dart';

import 'package:THLRedLook/models/danmaku/danmaku_models.dart';
import 'package:THLRedLook/utils/theme/app_colors.dart';
import 'package:THLRedLook/views/player/player_danmaku_blocked_words_sheet.dart';

class PlayerDanmakuSheetView extends StatefulWidget {
  const PlayerDanmakuSheetView({
    super.key,
    required this.enabled,
    required this.style,
    required this.onEnabledChanged,
    required this.onStyleChanged,
  });

  final bool enabled;
  final DanmakuStyle style;
  final Future<void> Function(bool) onEnabledChanged;
  final Future<void> Function(DanmakuStyle) onStyleChanged;

  static Future<void> show({
    required BuildContext context,
    required bool enabled,
    required DanmakuStyle style,
    required Future<void> Function(bool) onEnabledChanged,
    required Future<void> Function(DanmakuStyle) onStyleChanged,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.transparent,
    elevation: 0,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => PlayerDanmakuSheetView(
      enabled: enabled,
      style: style,
      onEnabledChanged: onEnabledChanged,
      onStyleChanged: onStyleChanged,
    ),
  );

  @override
  State<PlayerDanmakuSheetView> createState() => _PlayerDanmakuSheetViewState();
}

class _PlayerDanmakuSheetViewState extends State<PlayerDanmakuSheetView> {
  late DanmakuStyle _style = widget.style;
  late DanmakuStyle _savedStyle = widget.style;
  bool _saving = false;
  String? _error;

  Future<void> _saveStyle(DanmakuStyle next) async {
    setState(() {
      _style = next;
      _saving = true;
      _error = null;
    });
    try {
      await widget.onStyleChanged(next);
      _savedStyle = next;
    } catch (_) {
      if (mounted) {
        setState(() {
          _style = _savedStyle;
          _error = '未能保存设置，请重试。';
        });
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveControlStyle(DanmakuStyle next) async {
    try {
      await _saveStyle(next);
    } catch (_) {
      // The sheet shows the error and restores the last saved value.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('弹幕设置', style: theme.textTheme.titleLarge),
                    ),
                    TextButton(
                      key: const ValueKey('danmaku-reset'),
                      onPressed: _saving
                          ? null
                          : () => _saveControlStyle(
                              _style.copyWith(
                                opacity: 1,
                                fontSizeScale: 1,
                                speedScale: 1,
                                rows: 3,
                                mergeSeconds: 5,
                                shadowEnabled: true,
                              ),
                            ),
                      child: const Text('恢复默认'),
                    ),
                    IconButton(
                      tooltip: '关闭弹幕设置',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(_error!, style: TextStyle(color: colors.error)),
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              _slider(
                                id: 'opacity',
                                label: '不透明度',
                                current:
                                    '${(_style.opacity.clamp(.1, 1) * 100).round()}%',
                                value: _style.opacity.clamp(.1, 1),
                                min: .1,
                                max: 1,
                                divisions: 90,
                                onChanged: (value) =>
                                    _style.copyWith(opacity: value),
                              ),
                              _slider(
                                id: 'font-size',
                                label: '字体大小',
                                current: _style.fontSizeLabel,
                                value: _style.fontSizeStep.toDouble(),
                                max: 4,
                                divisions: 4,
                                onChanged: (value) => _style.copyWith(
                                  fontSizeScale:
                                      danmakuFontScales[value.round()],
                                ),
                              ),
                              _slider(
                                id: 'speed',
                                label: '移动速度',
                                current: _style.speedLabel,
                                value: _style.speedStep.toDouble(),
                                max: 4,
                                divisions: 4,
                                onChanged: (value) => _style.copyWith(
                                  speedScale: danmakuSpeedScales[value.round()],
                                ),
                              ),
                              _slider(
                                id: 'rows',
                                label: '显示行数',
                                current: '${_style.rows}行',
                                value: (_style.rows - 1).clamp(0, 3).toDouble(),
                                max: 3,
                                divisions: 3,
                                onChanged: (value) =>
                                    _style.copyWith(rows: value.round() + 1),
                              ),
                              _slider(
                                id: 'merge',
                                label: '合并弹幕',
                                current: '${_style.mergeSeconds}秒',
                                value: _style.mergeSeconds
                                    .clamp(2, 10)
                                    .toDouble(),
                                min: 2,
                                max: 10,
                                divisions: 8,
                                onChanged: (value) => _style.copyWith(
                                  mergeSeconds: value.round(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _card(
                        child: SwitchListTile.adaptive(
                          key: const ValueKey('danmaku-shadow-switch'),
                          title: const Text('弹幕阴影'),
                          subtitle: const Text('在文字下方显示阴影'),
                          value: _style.shadowEnabled,
                          activeThumbColor: AppColors.white,
                          activeTrackColor: AppColors.success,
                          onChanged: _saving
                              ? null
                              : (value) => _saveControlStyle(
                                  _style.copyWith(shadowEnabled: value),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _card(
                        child: ListTile(
                          key: const ValueKey('danmaku-blocked-words-settings'),
                          title: const Text('屏蔽词设置'),
                          subtitle: Text(
                            '${_style.blockedWordsEnabled ? '已开启' : '已关闭'} · ${_style.blockedWords.length}/$danmakuMaxBlockedWords',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _saving
                              ? null
                              : () => PlayerDanmakuBlockedWordsSheet.show(
                                  context: context,
                                  style: _style,
                                  onChanged: _saveStyle,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget _slider({
    required String id,
    required String label,
    required String current,
    required double value,
    double min = 0,
    required double max,
    required int divisions,
    required DanmakuStyle Function(double) onChanged,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        SizedBox(width: 72, child: Text(label)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 0),
              activeTrackColor: AppColors.hongguoRed.withValues(alpha: .5),
              thumbColor: AppColors.hongguoRed,
            ),
            child: Slider(
              key: ValueKey('danmaku-$id-slider'),
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: current,
              semanticFormatterCallback: (_) => '$label $current',
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _style = onChanged(value)),
              onChangeEnd: _saving ? null : (_) => _saveControlStyle(_style),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            current,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}
