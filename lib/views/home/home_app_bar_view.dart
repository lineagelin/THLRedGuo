import 'package:flutter/material.dart';

import 'package:THLRedLook/models/catalog/models.dart';

/// 首页顶部导航栏组件
class HomeAppBarView extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBarView({
    super.key,
    required this.selectionMode,
    required this.selectedEmpty,
    required this.tab,
    required this.sourceGroups,
    required this.group,
    required this.showRecommendations,
    required this.searchVisible,
    required this.television,
    required this.canDownload,
    required this.supportsDownloads,
    required this.supportsSourceManagement,
    required this.sourcesEmpty,
    required this.loading,
    required this.isUpdaterBusy,
    required this.catalogSortLabel,
    required this.isSortedOrFiltered,
    required this.screenWidth,
    required this.onClearSelection,
    required this.onCancelSelection,
    required this.onChangeGroup,
    required this.onChooseCatalogView,
    required this.onOpenRankings,
    required this.onStartSelection,
    required this.onToggleSearch,
    required this.onRefreshCatalog,
    required this.onMoreAction,
    this.onOpenSourceSwitcher,
    this.onFeedRefresh,
    this.onFeedMenu,
  });

  final bool selectionMode;
  final bool selectedEmpty;
  final int tab;
  final List<SourceGroup> sourceGroups;
  final SourceGroup group;
  final bool showRecommendations;
  final bool searchVisible;
  final bool television;
  final bool canDownload;
  final bool supportsDownloads;
  final bool supportsSourceManagement;
  final bool sourcesEmpty;
  final bool loading;
  final bool isUpdaterBusy;
  final String catalogSortLabel;
  final bool isSortedOrFiltered;
  final double screenWidth;

  final VoidCallback onClearSelection;
  final VoidCallback onCancelSelection;
  final ValueChanged<SourceGroup> onChangeGroup;
  final VoidCallback onChooseCatalogView;
  final VoidCallback onOpenRankings;
  final VoidCallback onStartSelection;
  final VoidCallback onToggleSearch;
  final VoidCallback onRefreshCatalog;
  final ValueChanged<String> onMoreAction;
  final VoidCallback? onOpenSourceSwitcher;
  final VoidCallback? onFeedRefresh;
  final VoidCallback? onFeedMenu;

  @override
  Size get preferredSize => Size.fromHeight(television ? 64.0 : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: tab == 4 ? Colors.transparent : null,
      foregroundColor: tab == 4 ? Colors.white : null,
      surfaceTintColor: tab == 4 ? Colors.transparent : null,
      forceMaterialTransparency: tab == 4,
      elevation: tab == 4 ? 0 : null,
      scrolledUnderElevation: tab == 4 ? 0 : null,
      toolbarHeight: television ? 64 : null,
      titleSpacing: 12,
      title: selectionMode
          ? const Text('选择短剧', maxLines: 1, overflow: TextOverflow.ellipsis)
          : Text(switch (tab) {
              4 => '推荐',
              5 => '我的',
              _ => '发现',
            }),
      centerTitle: false,
      actions: [
        if (selectionMode) ...[
          TextButton(
            key: const ValueKey('clear-catalog-selection'),
            onPressed: selectedEmpty ? null : onClearSelection,
            child: const Text('清空'),
          ),
          TextButton(
            key: const ValueKey('cancel-catalog-selection'),
            onPressed: onCancelSelection,
            child: const Text('取消'),
          ),
        ] else ...[
          if (tab == 5)
            IconButton(
              key: const ValueKey('my-settings'),
              tooltip: '设置',
              onPressed: () => onMoreAction('settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          if (tab == 4) ...[
            IconButton(
              key: const ValueKey('feed-refresh'),
              tooltip: '刷新推荐',
              onPressed: onFeedRefresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              key: const ValueKey('feed-search'),
              tooltip: '搜索',
              onPressed: onToggleSearch,
              icon: const Icon(Icons.search_rounded),
            ),

            IconButton(
              key: const ValueKey('feed-player-menu'),
              tooltip: '播放菜单',
              onPressed: onFeedMenu,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
          if (tab == 0) ...[
            if (!showRecommendations && screenWidth >= 850)
              IconButton(
                tooltip: '排序与筛选 · $catalogSortLabel',
                onPressed: onChooseCatalogView,
                color: isSortedOrFiltered
                    ? Theme.of(context).colorScheme.primary
                    : null,
                icon: const Icon(Icons.sort_rounded),
              ),
            IconButton(
              key: const ValueKey('open-rankings'),
              tooltip: '榜单',
              onPressed: sourcesEmpty ? null : onOpenRankings,
              icon: const Icon(Icons.leaderboard_outlined),
            ),
            if (!showRecommendations &&
                canDownload &&
                supportsDownloads &&
                screenWidth >= 850)
              IconButton(
                key: const ValueKey('select-catalog-dramas'),
                tooltip: '多选下载',
                onPressed: onStartSelection,
                icon: const Icon(Icons.checklist_rounded),
              ),
            IconButton(
              key: const ValueKey('toggle-search'),
              tooltip: searchVisible ? '收起搜索' : '搜索',
              icon: Icon(
                searchVisible ? Icons.search_off_rounded : Icons.search_rounded,
              ),
              onPressed: onToggleSearch,
            ),
          ],
        ],
      ],
    );
  }
}
