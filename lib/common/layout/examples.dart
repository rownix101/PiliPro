/// 响应式布局架构使用示例
///
/// 本文件提供了完整的代码示例，展示如何在 PiliPro 中使用新的响应式布局系统
library;

import 'package:PiliPro/common/layout/layout_orchestrator.dart';
import 'package:PiliPro/common/layout/layout_strategy.dart';
import 'package:PiliPro/common/layout/layout_types.dart';
import 'package:PiliPro/common/layout/responsive_widgets.dart';
import 'package:flutter/material.dart';

// ============================================================================
// 示例 1: 基础使用 - 最简单的响应式布局
// ============================================================================

class BasicExample extends StatelessWidget {
  final List<VideoItem> videos = []; // 你的视频数据

  BasicExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('基础示例')),
      body: ResponsiveLayoutBuilder(
        intent: BrowseIntent.discover, // 发现意图
        itemCount: videos.length,
        itemBuilder: (context, index) {
          return ResponsiveVideoCard(
            title: videos[index].title,
            coverUrl: videos[index].coverUrl,
            upName: videos[index].upName,
            duration: videos[index].duration,
            onTap: () => _playVideo(videos[index]),
          );
        },
      ),
    );
  }

  void _playVideo(VideoItem video) {
    // 播放视频
  }
}

// ============================================================================
// 示例 2: 完整功能 - 包含刷新、加载更多、头部
// ============================================================================

class FullFeatureExample extends StatefulWidget {
  const FullFeatureExample({super.key});

  @override
  State<FullFeatureExample> createState() => _FullFeatureExampleState();
}

class _FullFeatureExampleState extends State<FullFeatureExample> {
  List<VideoItem> _videos = [];
  bool _isLoading = false;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    // 模拟网络请求
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _videos = List.generate(20, (i) => VideoItem.mock(i));
      _isLoading = false;
    });
  }

  Future<void> _refreshVideos() async {
    _currentPage = 1;
    await _loadVideos();
  }

  void _loadMoreVideos() {
    if (_isLoading) return;
    _currentPage++;
    // 加载更多数据...
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('完整功能示例')),
      body: ResponsiveLayoutBuilder(
        intent: BrowseIntent.discover,
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          return ResponsiveVideoCard(
            title: _videos[index].title,
            coverUrl: _videos[index].coverUrl,
            upName: _videos[index].upName,
            viewCount: '${_videos[index].views}',
            danmakuCount: '${_videos[index].danmaku}',
            onTap: () => _playVideo(_videos[index]),
          );
        },
        header: _buildHeader(),
        footer: _buildFooter(),
        onRefresh: _refreshVideos,
        onLoadMore: _loadMoreVideos,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Text(
        '热门推荐',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const Text('没有更多内容了'),
    );
  }

  void _playVideo(VideoItem video) {}
}

// ============================================================================
// 示例 3: 内容感知布局 - 根据内容自动选择最佳布局
// ============================================================================

class ContentAwareExample extends StatefulWidget {
  const ContentAwareExample({super.key});

  @override
  State<ContentAwareExample> createState() => _ContentAwareExampleState();
}

class _ContentAwareExampleState extends State<ContentAwareExample> {
  final LayoutOrchestrator _orchestrator = LayoutOrchestrator();
  List<VideoItem> _videos = [];

  @override
  void initState() {
    super.initState();
    _initOrchestrator();
    _loadVideos();
  }

  void _initOrchestrator() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _orchestrator.initialize(
        context: context,
        defaultIntent: BrowseIntent.discover,
      );
      _orchestrator.addListener(() => setState(() {}));
    });
  }

  Future<void> _loadVideos() async {
    // 加载视频数据
    final videos = await _fetchVideos();
    setState(() => _videos = videos);

    // 分析内容并更新布局
    _orchestrator.updateContentProfile(videos, VideoContentExtractor());
  }

  Future<List<VideoItem>> _fetchVideos() async {
    // 模拟 API 调用
    await Future.delayed(const Duration(seconds: 1));
    return List.generate(20, (i) => VideoItem.mock(i));
  }

  @override
  void dispose() {
    _orchestrator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutConfigProvider(
      config: _orchestrator.currentConfig ?? LayoutConfig.grid(columns: 2),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('内容感知示例'),
          actions: [
            // 显示当前布局信息
            if (_orchestrator.currentConfig != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    '${_orchestrator.currentConfig!.type.name} '
                    '(${_orchestrator.currentConfig!.columns}列)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
        body: _videos.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ResponsiveLayoutBuilder(
                intent: BrowseIntent.discover,
                itemCount: _videos.length,
                itemBuilder: (context, index) => ResponsiveVideoCard(
                  title: _videos[index].title,
                  coverUrl: _videos[index].coverUrl,
                ),
              ),
      ),
    );
  }
}

// ============================================================================
// 示例 4: 自定义布局策略
// ============================================================================

class CustomStrategyExample extends StatelessWidget {
  final List<VideoItem> videos = [];

  CustomStrategyExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自定义策略示例')),
      body: FutureBuilder<LayoutConfig>(
        future: _calculateLayout(context),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return LayoutConfigProvider(
            config: snapshot.data!,
            child: ResponsiveLayoutBuilder(
              intent: BrowseIntent.discover,
              itemCount: videos.length,
              itemBuilder: (context, index) => ResponsiveVideoCard(
                title: videos[index].title,
                coverUrl: videos[index].coverUrl,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<LayoutConfig> _calculateLayout(BuildContext context) async {
    final metrics = ScreenMetrics.fromContext(context);

    // 自定义策略：如果视频标题平均长度超过 50，使用单列
    final avgTitleLength = videos.isEmpty
        ? 0
        : videos.map((v) => v.title.length).reduce((a, b) => a + b) /
              videos.length;

    if (avgTitleLength > 50) {
      return LayoutConfig.list(density: InformationDensity.high);
    }

    // 否则使用默认策略
    return LayoutStrategyEngine.recommendForScreen(metrics);
  }
}

// ============================================================================
// 示例 5: 平板侧边栏布局
// ============================================================================

class TabletLayoutExample extends StatelessWidget {
  final List<VideoItem> videos = [];

  TabletLayoutExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('平板布局示例')),
      body: ResponsiveLayoutBuilder(
        intent: BrowseIntent.discover,
        itemCount: videos.length,
        itemBuilder: (context, index) {
          // 获取当前配置
          final config = LayoutConfigProvider.of(context);

          return SidebarLayout(
            useSidebar: config?.useSidebar ?? false,
            sidebar: _buildSidebar(),
            content: _buildVideoGrid(),
          );
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: Colors.grey[200],
      child: ListView(
        children: const [
          ListTile(title: Text('首页')),
          ListTile(title: Text('热门')),
          ListTile(title: Text('分类')),
          ListTile(title: Text('关注')),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    return ResponsiveLayoutBuilder(
      intent: BrowseIntent.discover,
      itemCount: videos.length,
      itemBuilder: (context, index) => ResponsiveVideoCard(
        title: videos[index].title,
        coverUrl: videos[index].coverUrl,
      ),
    );
  }
}

// ============================================================================
// 示例 6: 搜索页面（单列布局）
// ============================================================================

class SearchExample extends StatefulWidget {
  const SearchExample({super.key});

  @override
  State<SearchExample> createState() => _SearchExampleState();
}

class _SearchExampleState extends State<SearchExample> {
  final TextEditingController _searchController = TextEditingController();
  List<VideoItem> _results = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '搜索视频...',
            border: InputBorder.none,
          ),
          onSubmitted: _performSearch,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _performSearch(_searchController.text),
          ),
        ],
      ),
      body: ResponsiveLayoutBuilder(
        intent: BrowseIntent.search, // 搜索意图 -> 单列列表
        itemCount: _results.length,
        itemBuilder: (context, index) => ResponsiveListItem(
          title: _results[index].title,
          coverUrl: _results[index].coverUrl,
          subtitle: '${_results[index].upName} · ${_results[index].views}次观看',
          onTap: () => _playVideo(_results[index]),
        ),
      ),
    );
  }

  void _performSearch(String query) async {
    // 执行搜索
    final results = await _fetchSearchResults(query);
    setState(() => _results = results);
  }

  Future<List<VideoItem>> _fetchSearchResults(String query) async {
    // 模拟搜索 API
    await Future.delayed(const Duration(milliseconds: 500));
    return List.generate(10, (i) => VideoItem.mock(i));
  }

  void _playVideo(VideoItem video) {}

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ============================================================================
// 示例 7: 骨架屏加载状态
// ============================================================================

class SkeletonExample extends StatelessWidget {
  final bool isLoading;
  final List<VideoItem> videos;

  const SkeletonExample({
    super.key,
    required this.isLoading,
    required this.videos,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('骨架屏示例')),
      body: isLoading
          ? const ResponsiveSkeleton(itemCount: 12)
          : ResponsiveLayoutBuilder(
              intent: BrowseIntent.discover,
              itemCount: videos.length,
              itemBuilder: (context, index) => ResponsiveVideoCard(
                title: videos[index].title,
                coverUrl: videos[index].coverUrl,
              ),
            ),
    );
  }
}

// ============================================================================
// 示例 8: 混合布局（网格 + 列表切换）
// ============================================================================

class HybridLayoutExample extends StatefulWidget {
  const HybridLayoutExample({super.key});

  @override
  State<HybridLayoutExample> createState() => _HybridLayoutExampleState();
}

class _HybridLayoutExampleState extends State<HybridLayoutExample> {
  final LayoutOrchestrator _orchestrator = LayoutOrchestrator();
  BrowseIntent _currentIntent = BrowseIntent.discover;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _orchestrator.initialize(
        context: context,
        defaultIntent: _currentIntent,
      );
    });
  }

  void _switchLayout(LayoutType type) {
    setState(() {
      switch (type) {
        case LayoutType.list:
          _currentIntent = BrowseIntent.search;
          break;
        case LayoutType.grid:
        case LayoutType.waterfall:
          _currentIntent = BrowseIntent.discover;
          break;
        default:
          _currentIntent = BrowseIntent.discover;
      }
    });
    _orchestrator.setIntent(_currentIntent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('混合布局示例'),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_list),
            onPressed: () => _switchLayout(LayoutType.list),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view),
            onPressed: () => _switchLayout(LayoutType.grid),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _orchestrator,
        builder: (context, child) {
          return ResponsiveLayoutBuilder(
            intent: _currentIntent,
            itemCount: 20,
            itemBuilder: (context, index) => ResponsiveVideoCard(
              title: '视频标题 $index',
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _orchestrator.dispose();
    super.dispose();
  }
}

// ============================================================================
// 辅助类和 Mock 数据
// ============================================================================

class VideoItem {
  final String title;
  final String? coverUrl;
  final String? upName;
  final String? duration;
  final int views;
  final int danmaku;

  VideoItem({
    required this.title,
    this.coverUrl,
    this.upName,
    this.duration,
    this.views = 0,
    this.danmaku = 0,
  });

  factory VideoItem.mock(int index) {
    return VideoItem(
      title: '视频标题 $index - 这是一个很长的标题用来测试布局效果',
      coverUrl: 'https://example.com/cover_$index.jpg',
      upName: 'UP主 $index',
      duration: '10:30',
      views: 10000 + index * 1000,
      danmaku: 100 + index * 10,
    );
  }
}

class VideoContentExtractor implements ContentExtractor<VideoItem> {
  @override
  String extractTitle(VideoItem item) => item.title;

  @override
  String extractType(VideoItem item) => 'video';

  @override
  double extractAspectRatio(VideoItem item) => 16 / 10;

  @override
  double estimateAverageHeight(List<VideoItem> items) => 200;
}
