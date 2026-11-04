import 'dart:async';

import 'package:flutter/material.dart';

import 'package:THLRedLook/core/bridge/core_bridge.dart';
import 'package:THLRedLook/core/download/download_collections.dart';
import 'package:THLRedLook/core/store/local_store.dart';
import 'package:THLRedLook/core/store/saved_library.dart';
import 'package:THLRedLook/models/catalog/models.dart';
import 'package:THLRedLook/pages/detail/detail_page.dart';
import 'package:THLRedLook/pages/downloads/downloads_page.dart';
import 'package:THLRedLook/pages/player/playback_launch_page.dart';
import 'package:THLRedLook/pages/settings/settings_page.dart';
import 'package:THLRedLook/views/common/widgets.dart';

class MyPage extends StatefulWidget {
  const MyPage({
    super.key,
    required this.repository,
    required this.store,
    required this.onSwitchSource,
    this.showHeader = true,
  });

  final bool showHeader;
  final AppRepository repository;
  final LocalStore store;
  final Future<void> Function() onSwitchSource;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  List<DownloadJob> _jobs = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _downloadError;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refreshDownloads();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshDownloads(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshDownloads() async {
    if (_refreshing) return;
    _refreshing = true;
    final epoch = widget.store.profileEpoch;
    try {
      final jobs =
          widget.store.canDownload && widget.repository.supportsDownloads
          ? await widget.repository.downloads()
          : <DownloadJob>[];
      if (mounted && epoch == widget.store.profileEpoch) {
        setState(() {
          _jobs = jobs;
          _downloadError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _downloadError = '下载记录暂时无法读取');
    } finally {
      _refreshing = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDownloads() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DownloadsScreen(
          repository: widget.repository,
          store: widget.store,
          allSources: true,
        ),
      ),
    );
    if (mounted) await _refreshDownloads();
  }

  void _openDrama(Drama drama, {bool download = false}) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => download
            ? DetailScreen(
                drama: drama,
                repository: widget.repository,
                store: widget.store,
                downloadOnOpen: true,
              )
            : PlaybackLaunchScreen(
                drama: drama,
                repository: widget.repository,
                store: widget.store,
              ),
      ),
    );
  }

  void _openLibrary({required bool history}) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: SavedLibrary(
              repository: widget.repository,
              store: widget.store,
              history: history,
              allSources: true,
              showBackButton: true,
              onOpen: _openDrama,
              onContinue: _openDrama,
              onDownload:
                  widget.store.canDownload &&
                      widget.repository.supportsDownloads
                  ? (drama) => _openDrama(drama, download: true)
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String id,
    required String title,
    required IconData icon,
    required int count,
    required VoidCallback onViewAll,
    required Widget child,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title · $count',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: ValueKey('my-all-$id'),
                onPressed: onViewAll,
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );

  Widget _previews(
    String id,
    List<Drama> dramas,
    String Function(Drama) subtitle,
    void Function(Drama) onTap,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var index = 0; index < 3; index++) ...[
        if (index > 0) const SizedBox(width: 12),
        Expanded(
          child: index >= dramas.length
              ? const SizedBox.shrink()
              : InkWell(
                  key: ValueKey('my-$id-${dramas[index].id}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTap(dramas[index]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 2 / 3,
                        child: DramaCover(
                          drama: dramas[index],
                          repository: widget.repository,
                          radius: 12,
                          showEpisodeCount: false,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dramas[index].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle(dramas[index]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final favorites = widget.store.favorites;
      final history = widget.store.history;
      final downloads = downloadCollections(
        widget.store.canDownload
            ? _jobs.where((job) => widget.store.allowsSource(job.drama.source))
            : const <DownloadJob>[],
      );
      final source = SourceSite.byId(widget.store.source);
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: RefreshIndicator(
            onRefresh: _refreshDownloads,
            child: ListView(
              key: const PageStorageKey('my-page'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (widget.showHeader)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '我的',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: '设置',
                        key: const ValueKey('my-settings'),
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              repository: widget.repository,
                              store: widget.store,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    key: const ValueKey('my-source-switch'),
                    leading: const Icon(Icons.video_library_outlined),
                    title: const Text('数据源'),
                    subtitle: Text(
                      widget.store.sources.isEmpty ? '暂未添加数据源' : source.name,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: widget.onSwitchSource,
                  ),
                ),
                _section(
                  id: 'favorites',
                  title: '追剧',
                  icon: Icons.bookmark_outline,
                  count: favorites.length,
                  onViewAll: () => _openLibrary(history: false),
                  child: favorites.isEmpty
                      ? const Text('还没有追剧，去发现页收藏喜欢的短剧。')
                      : _previews(
                          'favorites',
                          favorites.take(3).toList(),
                          (drama) =>
                              widget.store.following(drama.id)?.label ?? '已收藏',
                          _openDrama,
                        ),
                ),
                _section(
                  id: 'history',
                  title: '最近观看',
                  icon: Icons.history_rounded,
                  count: history.length,
                  onViewAll: () => _openLibrary(history: true),
                  child: history.isEmpty
                      ? const Text('还没有观看记录。')
                      : _previews(
                          'history',
                          history.take(3).map((entry) => entry.drama).toList(),
                          (drama) {
                            final watch = widget.store.watched(drama.id)!;
                            return '第 ${watch.episode} 集 · ${formatPosition(watch.position)}';
                          },
                          _openDrama,
                        ),
                ),
                _section(
                  id: 'downloads',
                  title: '下载',
                  icon: Icons.download_outlined,
                  count: downloads.length,
                  onViewAll: _openDownloads,
                  child: _loading
                      ? const LinearProgressIndicator()
                      : _downloadError != null
                      ? Row(
                          children: [
                            Expanded(child: Text(_downloadError!)),
                            TextButton(
                              onPressed: _refreshDownloads,
                              child: const Text('重试'),
                            ),
                          ],
                        )
                      : downloads.isEmpty
                      ? Text(
                          widget.store.canDownload
                              ? '还没有下载记录。'
                              : '当前用户未开放下载权限。',
                        )
                      : _previews(
                          'downloads',
                          downloads
                              .take(3)
                              .map((entry) => entry.drama)
                              .toList(),
                          (drama) {
                            final collection = downloads.firstWhere(
                              (entry) => entry.drama.id == drama.id,
                            );
                            return '已下载 ${collection.completed}/${collection.jobs.length} 集';
                          },
                          (_) => _openDownloads(),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
