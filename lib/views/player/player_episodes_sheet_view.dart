import 'dart:math';
import 'package:flutter/material.dart';
import 'package:THLRedLook/core/bridge/core_bridge.dart';
import 'package:THLRedLook/core/series/hongguo_series.dart';
import 'package:THLRedLook/core/store/local_store.dart';
import 'package:THLRedLook/models/catalog/models.dart';
import 'package:THLRedLook/utils/theme/app_colors.dart';
import 'package:THLRedLook/views/common/widgets.dart';

class PlayerEpisodesSheetView extends StatefulWidget {
  const PlayerEpisodesSheetView({
    super.key,
    required this.episodes,
    required this.currentIndex,
    required this.onEpisodeSelected,
    this.dramaTitle,
    this.drama,
    this.repository,
    this.store,
    this.seriesEntries = const [],
    this.currentDramaId,
    this.onSeasonSelected,
  });
  final List<Episode> episodes;
  final int currentIndex;
  final ValueChanged<int> onEpisodeSelected;
  final String? dramaTitle;
  final Drama? drama;
  final AppRepository? repository;
  final LocalStore? store;
  final List<HongguoSeriesEntry> seriesEntries;
  final String? currentDramaId;
  final ValueChanged<Drama>? onSeasonSelected;
  @override
  State<PlayerEpisodesSheetView> createState() =>
      _PlayerEpisodesSheetViewState();
}

class _PlayerEpisodesSheetViewState extends State<PlayerEpisodesSheetView> {
  static const _groupSize = 50;
  late int _group = max(0, widget.currentIndex) ~/ _groupSize;
  late final _ranges = ScrollController(initialScrollOffset: _group * 88.0);
  final _grid = ScrollController();
  String? _gridLayout;
  bool _saving = false;
  @override
  void dispose() {
    _ranges.dispose();
    _grid.dispose();
    super.dispose();
  }

  Widget _cover(Drama drama, double width) => SizedBox(
    width: width,
    height: width * 1.4,
    child: widget.repository == null
        ? const Icon(Icons.movie_outlined)
        : DramaCover(
            drama: drama,
            repository: widget.repository!,
            radius: 8,
            showOverlay: false,
            showEpisodeCount: false,
          ),
  );

  Future<void> _favorite() async {
    if (_saving || widget.store == null || widget.drama == null) return;
    setState(() => _saving = true);
    try {
      await widget.store!.toggleFavorite(widget.drama!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未能保存收藏，请重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _header() {
    final drama = widget.drama;
    final entry = widget.seriesEntries
        .where((e) => e.drama.id == widget.currentDramaId)
        .firstOrNull;
    final subtitle = [
      if (entry != null) entry.label,
      if (drama != null && drama.releaseStatus.isNotEmpty) drama.releaseLabel,
      '全${widget.episodes.length}集',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          if (drama != null) ...[_cover(drama, 52), const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drama?.title ?? widget.dramaTitle ?? '选集',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (widget.store != null && drama != null) ...[
            const SizedBox(width: 12),
            ListenableBuilder(
              listenable: widget.store!,
              builder: (context, _) => FilledButton(
                onPressed: _saving ? null : _favorite,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.hongguoRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(widget.store!.isFavorite(drama.id) ? '已收藏' : '收藏'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _intro() {
    final drama = widget.drama;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: [
        Text(
          drama?.description.trim().isNotEmpty == true
              ? drama!.description
              : '暂无简介',
          style: const TextStyle(fontSize: 16, height: 1.7),
        ),
        if (drama != null && drama.tags.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in drama.tags) Chip(label: Text(tag))],
          ),
        ],
      ],
    );
  }

  Widget _episodes() {
    final episodes = widget.episodes;
    if (episodes.isEmpty) return const Center(child: Text('暂无可播放集数'));
    final groups = (episodes.length / _groupSize).ceil();
    _group = _group.clamp(0, groups - 1);
    final start = _group * _groupSize;
    final end = min(start + _groupSize, episodes.length);
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 60,
          child: ListView.builder(
            controller: _ranges,
            scrollDirection: Axis.horizontal,
            itemExtent: 88,
            itemCount: groups,
            itemBuilder: (context, index) {
              final first = index * _groupSize;
              final last = min(first + _groupSize, episodes.length) - 1;
              return TextButton(
                key: ValueKey('episode-group-$index'),
                onPressed: () => setState(() {
                  _group = index;
                  if (_grid.hasClients) _grid.jumpTo(0);
                }),
                style: TextButton.styleFrom(
                  foregroundColor: _group == index
                      ? colors.onSurface
                      : colors.onSurfaceVariant,
                ),
                child: Text(
                  '${episodes[first].number}-${episodes[last].number}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: _group == index
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 10 : 6;
              final layout =
                  '$_group:${constraints.maxWidth}:${constraints.maxHeight}:${widget.currentIndex}';
              if (_gridLayout != layout) {
                _gridLayout = layout;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_grid.hasClients || _gridLayout != layout) {
                    return;
                  }
                  final row = (widget.currentIndex - start) ~/ columns;
                  final stride =
                      (constraints.maxWidth - (columns - 1) * 10) / columns +
                      10;
                  final offset =
                      widget.currentIndex >= start && widget.currentIndex < end
                      ? row * stride - constraints.maxHeight / 2 + stride / 2
                      : 0.0;
                  _grid.jumpTo(
                    offset.clamp(0.0, _grid.position.maxScrollExtent),
                  );
                });
              }
              return GridView.builder(
                controller: _grid,
                padding: const EdgeInsets.only(bottom: 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: end - start,
                itemBuilder: (context, offset) {
                  final index = start + offset;
                  final active = index == widget.currentIndex;
                  final color = active
                      ? AppColors.hongguoRed
                      : colors.onSurfaceVariant;
                  return Material(
                    color: active
                        ? AppColors.hongguoRed.withValues(alpha: .20)
                        : colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('sheet-episode-${episodes[index].number}'),
                      onTap: () => widget.onEpisodeSelected(index),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '${episodes[index].number}',
                            style: TextStyle(
                              color: color,
                              fontSize: 17,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          if (active)
                            Positioned(
                              top: 5,
                              right: 5,
                              child: Icon(
                                Icons.equalizer_rounded,
                                color: color,
                                size: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _series() {
    final entries = widget.seriesEntries;
    if (entries.isEmpty) return const Center(child: Text('暂无系列剧'));
    final colors = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 18),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final current = entry.drama.id == widget.currentDramaId;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _cover(entry.drama, 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.drama.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        entry.label,
                        if (entry.drama.heat.isNotEmpty)
                          '${entry.drama.heat}热度',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed:
                    current ||
                        !entry.playable ||
                        widget.onSeasonSelected == null
                    ? null
                    : () => widget.onSeasonSelected!(entry.drama),
                child: Text(
                  current
                      ? '播放中'
                      : entry.playable
                      ? '播放'
                      : '暂不可播',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height:
              media.size.height *
              (media.orientation == Orientation.landscape ? .88 : .62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.whiteWithAlpha(.18),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                _header(),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerHeight: 0,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: TextStyle(fontSize: 18),
                  tabs: [
                    Tab(text: '简介'),
                    Tab(text: '选集'),
                    Tab(text: '系列剧'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [_intro(), _episodes(), _series()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
