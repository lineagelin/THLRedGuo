import 'package:flutter/material.dart';
import 'package:THLRedLook/core/player/playback_preferences.dart';
import 'package:THLRedLook/utils/theme/app_colors.dart';

enum PlayerQuickAction { danmakuSettings, download, cast, sleep }

class PlayerQuickMenuSheet extends StatefulWidget {
  const PlayerQuickMenuSheet({
    super.key,
    required this.preferences,
    required this.qualities,
    required this.onPreferences,
    this.danmakuSupported = true,
    this.canDownload = true,
    this.canCast = true,
    this.canPip = true,
    this.cleanScreen = false,
    this.sleepLabel = '未开启',
  });
  final PlaybackPreferences preferences;
  final List<int> qualities;
  final Future<void> Function(PlaybackPreferences) onPreferences;
  final bool danmakuSupported, canDownload, canCast, canPip, cleanScreen;
  final String sleepLabel;

  static Future<PlayerQuickAction?> show(
    BuildContext context, {
    required PlaybackPreferences preferences,
    required List<int> qualities,
    required Future<void> Function(PlaybackPreferences) onPreferences,
    required bool danmakuSupported,
    required bool canDownload,
    required bool canCast,
    required bool canPip,
    required bool cleanScreen,
    required String sleepLabel,
  }) => showModalBottomSheet<PlayerQuickAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (_) => PlayerQuickMenuSheet(
      preferences: preferences,
      qualities: qualities,
      onPreferences: onPreferences,
      danmakuSupported: danmakuSupported,
      canDownload: canDownload,
      canCast: canCast,
      canPip: canPip,
      cleanScreen: cleanScreen,
      sleepLabel: sleepLabel,
    ),
  );
  @override
  State<PlayerQuickMenuSheet> createState() => _PlayerQuickMenuSheetState();
}

class _PlayerQuickMenuSheetState extends State<PlayerQuickMenuSheet> {
  late PlaybackPreferences _prefs = widget.preferences;
  bool _busy = false;
  String? _error;
  Future<void> _save(PlaybackPreferences next) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onPreferences(next);
      if (mounted) setState(() => _prefs = next);
    } catch (_) {
      if (mounted) setState(() => _error = '未能保存，请重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final qualities = {0, ...widget.qualities.where((q) => q > 0)}.toList()
      ..sort();
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: colors.error)),
                  ),
                _group([
                  _options(Icons.speed_rounded, '倍速', [
                    for (final speed in const [.75, 1.0, 1.25, 1.5, 2.0, 3.0])
                      _MenuChoice(
                        'quick-speed-$speed',
                        '${speed == speed.roundToDouble() ? speed.toInt() : speed}x',
                        _prefs.speed == speed,
                        () => _save(_prefs.copyWith(speed: speed)),
                      ),
                  ]),
                  _options(Icons.hd_outlined, '清晰度', [
                    for (final quality in qualities)
                      _MenuChoice(
                        'quick-quality-$quality',
                        quality == 0 ? '自动' : '${quality}P',
                        _prefs.quality == quality,
                        () => _save(_prefs.copyWith(quality: quality)),
                      ),
                  ]),
                  _switch(
                    'quick-danmaku',
                    Icons.subtitles_outlined,
                    '弹幕',
                    value: _prefs.danmaku,
                    supported: widget.danmakuSupported,
                    hint: widget.danmakuSupported ? null : '当前剧集不支持弹幕',
                    onChanged: (value) =>
                        _save(_prefs.copyWith(danmaku: value)),
                  ),
                  _item(
                    Icons.tune_rounded,
                    '弹幕设置',
                    PlayerQuickAction.danmakuSettings,
                    enabled: widget.danmakuSupported,
                  ),
                  _item(
                    Icons.download_outlined,
                    '下载到本地',
                    PlayerQuickAction.download,
                    enabled: widget.canDownload,
                  ),
                ]),
                const SizedBox(height: 14),
                _group([
                  _item(
                    Icons.cast_rounded,
                    '投屏',
                    PlayerQuickAction.cast,
                    enabled: widget.canCast,
                  ),
                  _item(
                    Icons.timer_outlined,
                    '定时关闭',
                    PlayerQuickAction.sleep,
                    value: widget.sleepLabel == '未开启'
                        ? null
                        : widget.sleepLabel,
                  ),
                  _switch(
                    'quick-pip',
                    Icons.picture_in_picture_alt_rounded,
                    '小窗模式',
                    value: _prefs.pictureInPicture,
                    supported: widget.canPip,
                    hint: widget.canPip ? null : '当前设备不支持小窗',
                    onChanged: (value) =>
                        _save(_prefs.copyWith(pictureInPicture: value)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _group(List<Widget> children) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: children),
    ),
  );

  Widget _item(
    IconData icon,
    String title,
    PlayerQuickAction action, {
    bool enabled = true,
    String? value,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      key: ValueKey('quick-${action.name}'),
      minTileHeight: 64,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 26,
      horizontalTitleGap: 12,
      leading: Icon(icon, size: 26),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(
              value,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: colors.onSurfaceVariant,
            size: 23,
          ),
        ],
      ),
      enabled: enabled && !_busy,
      onTap: () => Navigator.pop(context, action),
    );
  }

  Widget _switch(
    String key,
    IconData icon,
    String title, {
    required bool value,
    required bool supported,
    String? hint,
    required ValueChanged<bool> onChanged,
  }) => ListTile(
    key: ValueKey(key),
    minTileHeight: 64,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    minLeadingWidth: 26,
    horizontalTitleGap: 12,
    leading: Icon(icon, size: 26),
    title: Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    subtitle: hint == null
        ? null
        : Text(hint, style: const TextStyle(fontSize: 11)),
    trailing: Switch.adaptive(
      value: value,
      activeTrackColor: AppColors.success,
      activeThumbColor: AppColors.white,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: supported && !_busy ? onChanged : null,
    ),
    enabled: supported && !_busy,
    onTap: supported && !_busy ? () => onChanged(!value) : null,
  );

  Widget _options(IconData icon, String title, List<_MenuChoice> choices) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: ValueKey('quick-options-$title'),
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 26),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final naturalWidth = choices.length * 48.0 + 6;
                final minimumWidth = choices.length * 36.0 + 6;
                final viewportWidth = constraints.maxWidth < naturalWidth
                    ? constraints.maxWidth
                    : naturalWidth;
                final contentWidth = viewportWidth < minimumWidth
                    ? minimumWidth
                    : viewportWidth;
                return Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: viewportWidth,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        width: contentWidth,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: dark
                              ? AppColors.darkSurfaceHigh
                              : AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            for (final choice in choices)
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  selected: choice.selected,
                                  enabled: !_busy,
                                  label: '$title ${choice.label}',
                                  child: Material(
                                    color: choice.selected
                                        ? (dark
                                              ? AppColors.darkSurfaceHighest
                                              : AppColors.lightSurface)
                                        : AppColors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      key: ValueKey(choice.key),
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: _busy ? null : choice.onTap,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            choice.label,
                                            maxLines: 1,
                                            softWrap: false,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: choice.selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                              color: choice.selected
                                                  ? colors.onSurface
                                                  : colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuChoice {
  const _MenuChoice(this.key, this.label, this.selected, this.onTap);
  final String key, label;
  final bool selected;
  final VoidCallback onTap;
}
