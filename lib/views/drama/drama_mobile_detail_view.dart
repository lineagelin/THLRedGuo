import 'package:flutter/material.dart';
import 'package:THLRedLook/core/bridge/core_bridge.dart';
import 'package:THLRedLook/models/catalog/models.dart';
import 'package:THLRedLook/utils/theme/app_colors.dart';
import 'package:THLRedLook/utils/theme/app_theme.dart';
import 'package:THLRedLook/views/common/widgets.dart';

class DramaMobileDetailView extends StatefulWidget {
  const DramaMobileDetailView({
    super.key,
    required this.drama,
    required this.episodes,
    required this.repository,
    required this.currentIndex,
    required this.favorite,
    required this.onFavorite,
    required this.onPlay,
    required this.onAllEpisodes,
    required this.onBack,
    required this.onCover,
    required this.onRefresh,
    required this.loading,
    required this.allowed,
    this.error,
    this.hasWatchHistory = false,
    this.seriesSelector,
    this.recommendations = const [],
    required this.onRecommendation,
  });
  final Drama drama;
  final List<Episode> episodes;
  final AppRepository repository;
  final int currentIndex;
  final bool favorite, loading, allowed;
  final bool hasWatchHistory;
  final String? error;
  final Widget? seriesSelector;
  final List<Drama> recommendations;
  final VoidCallback onFavorite, onAllEpisodes, onBack, onCover, onRefresh;
  final ValueChanged<int> onPlay;
  final ValueChanged<Drama> onRecommendation;
  @override
  State<DramaMobileDetailView> createState() => _DramaMobileDetailViewState();
}

class _DramaMobileDetailViewState extends State<DramaMobileDetailView> {
  final _overview = GlobalKey(),
      _episodes = GlobalKey(),
      _recommendations = GlobalKey();
  bool _expanded = false;
  void _scroll(GlobalKey key) {
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 250),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final drama = widget.drama;
    final meta = [
      if (widget.episodes.isNotEmpty) '全${widget.episodes.length}集',
      if (drama.heat.isNotEmpty) '${drama.heat}热度',
      if (drama.views.isNotEmpty) '${drama.views}播放',
      if (drama.releaseStatus.isNotEmpty && drama.releaseStatus != 'unknown')
        drama.releaseLabel,
    ];
    final tags = {
      if (drama.category.isNotEmpty) drama.displayCategory,
      ...drama.tags,
    };
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: AppColors.playerSceneDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            DramaBackdrop(
              drama: drama,
              repository: widget.repository,
              sigma: 44,
              dimColor: AppColors.blackWithAlpha(.65),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: '返回',
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '更新剧集信息',
                        onPressed: widget.loading ? null : widget.onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  Expanded(
                    child: !widget.allowed
                        ? const Center(child: Text('当前用户无权访问'))
                        : SingleChildScrollView(
                            key: const ValueKey('mobile-detail-scroll'),
                            padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      key: const ValueKey(
                                        'mobile-detail-cover',
                                      ),
                                      onTap: widget.onCover,
                                      child: SizedBox(
                                        width: 108,
                                        height: 162,
                                        child: DramaCover(
                                          drama: drama,
                                          repository: widget.repository,
                                          radius: 12,
                                          showEpisodeCount: false,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            drama.title,
                                            style: const TextStyle(
                                              color: AppColors.white,
                                              fontSize: 23,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          if (meta.isNotEmpty)
                                            Text(
                                              meta.join(' · '),
                                              style: const TextStyle(
                                                color:
                                                    AppColors.textSecondaryDark,
                                                height: 1.7,
                                              ),
                                            ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              for (final tag in tags.take(6))
                                                Chip(label: Text(tag)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                const Divider(),
                                Wrap(
                                  spacing: 16,
                                  children: [
                                    TextButton(
                                      onPressed: () => _scroll(_overview),
                                      child: const Text('基本信息'),
                                    ),
                                    TextButton(
                                      onPressed: () => _scroll(_episodes),
                                      child: const Text('选集'),
                                    ),
                                    if (widget.recommendations.isNotEmpty)
                                      TextButton(
                                        onPressed: () =>
                                            _scroll(_recommendations),
                                        child: const Text('猜你喜欢'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Column(
                                  key: _overview,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      drama.description.isEmpty
                                          ? '暂无简介'
                                          : drama.description,
                                      maxLines: _expanded ? null : 3,
                                      overflow: _expanded
                                          ? TextOverflow.visible
                                          : TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textSecondaryDark,
                                        fontSize: 15,
                                        height: 1.8,
                                      ),
                                    ),
                                    if (drama.description.length > 60)
                                      TextButton(
                                        onPressed: () => setState(
                                          () => _expanded = !_expanded,
                                        ),
                                        child: Text(_expanded ? '收起' : '展开'),
                                      ),
                                    if (drama.onlineDate.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text('上线时间：${drama.onlineDate}'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  key: _episodes,
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        '选集',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 21,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: widget.episodes.isEmpty
                                          ? null
                                          : widget.onAllEpisodes,
                                      child: Text(
                                        widget.episodes.isEmpty
                                            ? '暂无分集'
                                            : '共${widget.episodes.length}集 ›',
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.seriesSelector != null)
                                  widget.seriesSelector!,
                                if (widget.loading)
                                  const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else if (widget.error != null ||
                                    widget.episodes.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    child: Text(widget.error ?? '暂时没有可播放的集数'),
                                  )
                                else
                                  SizedBox(
                                    height: 68,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: widget.episodes.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(width: 10),
                                      itemBuilder: (_, index) => SizedBox(
                                        width: 62,
                                        child: FilledButton.tonal(
                                          key: ValueKey(
                                            'mobile-detail-episode-$index',
                                          ),
                                          onPressed: () => widget.onPlay(index),
                                          style: FilledButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            backgroundColor:
                                                index == widget.currentIndex
                                                ? AppColors.hongguoRed
                                                : AppColors.whiteWithAlpha(.12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (index == widget.currentIndex)
                                                const Icon(
                                                  Icons.equalizer_rounded,
                                                  size: 14,
                                                ),
                                              Text(
                                                '${widget.episodes[index].number}',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (widget.recommendations.isNotEmpty) ...[
                                  const SizedBox(height: 32),
                                  Text(
                                    '猜你喜欢',
                                    key: _recommendations,
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: widget.recommendations.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 16,
                                          childAspectRatio: .62,
                                        ),
                                    itemBuilder: (_, index) {
                                      final item =
                                          widget.recommendations[index];
                                      return InkWell(
                                        onTap: () =>
                                            widget.onRecommendation(item),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                width: double.infinity,
                                                child: DramaCover(
                                                  drama: item,
                                                  repository: widget.repository,
                                                  radius: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('mobile-detail-favorite'),
                    onPressed: widget.allowed ? widget.onFavorite : null,
                    icon: Icon(
                      widget.favorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                    ),
                    label: Text(widget.favorite ? '已收藏' : '收藏'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('mobile-detail-continue'),
                    onPressed:
                        widget.allowed &&
                            !widget.loading &&
                            widget.episodes.isNotEmpty
                        ? () => widget.onPlay(widget.currentIndex)
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(widget.hasWatchHistory ? '继续播放' : '立即播放'),
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
