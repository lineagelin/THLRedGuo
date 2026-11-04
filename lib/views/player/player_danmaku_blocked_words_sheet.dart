import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:THLRedLook/models/danmaku/danmaku_models.dart';
import 'package:THLRedLook/utils/theme/app_colors.dart';

class PlayerDanmakuBlockedWordsSheet extends StatefulWidget {
  const PlayerDanmakuBlockedWordsSheet({
    super.key,
    required this.style,
    required this.onChanged,
  });

  final DanmakuStyle style;
  final Future<void> Function(DanmakuStyle) onChanged;

  static Future<void> show({
    required BuildContext context,
    required DanmakuStyle style,
    required Future<void> Function(DanmakuStyle) onChanged,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.transparent,
    elevation: 0,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) =>
        PlayerDanmakuBlockedWordsSheet(style: style, onChanged: onChanged),
  );

  @override
  State<PlayerDanmakuBlockedWordsSheet> createState() =>
      _PlayerDanmakuBlockedWordsSheetState();
}

class _PlayerDanmakuBlockedWordsSheetState
    extends State<PlayerDanmakuBlockedWordsSheet> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  late DanmakuStyle _style = widget.style;
  bool _adding = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<bool> _save(DanmakuStyle next) async {
    final previous = _style;
    setState(() {
      _style = next;
      _saving = true;
      _error = null;
    });
    try {
      await widget.onChanged(next);
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _style = previous;
          _error = '未能保存屏蔽词，请重试。';
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addWord() async {
    if (_saving) return;
    final word = _input.text.trim();
    final String? error;
    if (word.isEmpty) {
      error = '请输入屏蔽词';
    } else if (word.characters.length > danmakuMaxWordLength) {
      error = '屏蔽词最多 $danmakuMaxWordLength 个字';
    } else if (_style.blockedWords.any(
      (item) => item.toLowerCase() == word.toLowerCase(),
    )) {
      error = '该屏蔽词已存在';
    } else if (_style.blockedWords.length >= danmakuMaxBlockedWords) {
      error = '最多添加 $danmakuMaxBlockedWords 个屏蔽词';
    } else {
      error = null;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (await _save(
          _style.copyWith(blockedWords: [..._style.blockedWords, word]),
        ) &&
        mounted) {
      _input.clear();
      _inputFocus.unfocus();
      setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final media = MediaQuery.of(context);
    final height = math
        .min(
          media.size.height * .65,
          media.size.height - media.viewInsets.bottom - media.padding.top - 24,
        )
        .clamp(0.0, media.size.height);
    final compactInput = height < 300 && (_adding || media.viewInsets.bottom > 0);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Material(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              if (!compactInput) ...[
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '屏蔽词设置',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭屏蔽词设置',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                  child: Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: SwitchListTile.adaptive(
                      key: const ValueKey('danmaku-blocked-words-switch'),
                      title: const Text('开启屏蔽词'),
                      value: _style.blockedWordsEnabled,
                      activeThumbColor: AppColors.white,
                      activeTrackColor: AppColors.success,
                      onChanged: _saving
                          ? null
                          : (value) => _save(
                              _style.copyWith(blockedWordsEnabled: value),
                            ),
                    ),
                  ),
                ),
              ],
              Expanded(
                child: _style.blockedWords.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '添加屏蔽词后，将不会看到包含此词汇的弹幕\n例如：添加“6”，可以屏蔽“666”“真6啊”',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              height: 1.6,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        itemCount: _style.blockedWords.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final word = _style.blockedWords[index];
                          return Material(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              title: Text(word),
                              trailing: IconButton(
                                key: ValueKey('danmaku-delete-word-$word'),
                                tooltip: '删除屏蔽词 $word',
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: _saving
                                    ? null
                                    : () => _save(
                                        _style.copyWith(
                                          blockedWords: _style.blockedWords
                                              .where((item) => item != word)
                                              .toList(),
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(_error!, style: TextStyle(color: colors.error)),
                ),
              Material(
                color: colors.surface,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      compactInput ? 4 : 12,
                      16,
                      compactInput ? 4 : 12,
                    ),
                    child: _adding
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const ValueKey(
                                    'danmaku-blocked-word-input',
                                  ),
                                  controller: _input,
                                  focusNode: _inputFocus,
                                  autofocus: true,
                                  enabled: !_saving,
                                  maxLength: danmakuMaxWordLength,
                                  textInputAction: TextInputAction.done,
                                  decoration: InputDecoration(
                                    hintText: '输入10个字以内的屏蔽词',
                                    isDense: compactInput,
                                    counterText: compactInput ? '' : null,
                                  ),
                                  onSubmitted: (_) => _addWord(),
                                ),
                              ),
                              TextButton(
                                key: const ValueKey('danmaku-confirm-word'),
                                onPressed: _saving ? null : _addWord,
                                child: const Text('添加'),
                              ),
                              IconButton(
                                tooltip: '取消添加',
                                onPressed: _saving
                                    ? null
                                    : () {
                                        _inputFocus.unfocus();
                                        _input.clear();
                                        setState(() {
                                          _adding = false;
                                          _error = null;
                                        });
                                      },
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              key: const ValueKey('danmaku-add-blocked-word'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.hongguoRed,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed:
                                  _saving ||
                                      _style.blockedWords.length >=
                                          danmakuMaxBlockedWords
                                  ? null
                                  : () => setState(() {
                                      _adding = true;
                                      _error = null;
                                    }),
                              child: Text(
                                '添加屏蔽词（${_style.blockedWords.length}/$danmakuMaxBlockedWords）',
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
    );
  }
}
