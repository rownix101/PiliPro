# 响应式布局架构文档

## 概述

响应式布局架构（Responsive Layout Architecture）是 PiliPro 的新一代布局系统，旨在解决当前布局系统的碎片化问题，提供统一的、智能的、自适应的布局解决方案。

## 架构设计

### 核心组件

```
┌─────────────────────────────────────────────────────────────┐
│                    LayoutOrchestrator                       │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐    │
│  │DeviceSensor │  │ContentAnalyzer│  │LayoutStrategy  │    │
│  └─────────────┘  └─────────────┘  └──────────────────┘    │
│                                                             │
│  职责：监听变化 + 协调决策 + 管理状态                        │
└─────────────────────────────────────────────────────────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
    ┌─────────────────┐ ┌────────────────┐ ┌────────────────┐
    │  GridRenderer   │ │WaterfallRenderer│ │ ListRenderer   │
    └─────────────────┘ └────────────────┘ └────────────────┘
```

### 1. LayoutOrchestrator

中央协调器，单例模式管理全局布局状态。

**职责：**
- 监听设备和屏幕变化
- 协调内容分析和布局决策
- 管理用户偏好
- 触发布局更新

**使用方式：**

```dart
// 初始化
final orchestrator = LayoutOrchestrator();
orchestrator.initialize(
  context: context,
  defaultIntent: BrowseIntent.discover,
);

// 监听变化
orchestrator.addListener(() {
  setState(() {});
});

// 更改意图
orchestrator.setIntent(BrowseIntent.search);

// 更新内容分析
orchestrator.updateContentProfile(videos, VideoContentExtractor());
```

### 2. DeviceSensor

设备感知层，监听屏幕尺寸、方向、设备类型等变化。

**特性：**
- 自动检测折叠屏状态
- 支持平板/手机区分
- 监听横竖屏切换

**使用方式：**

```dart
final sensor = DeviceSensor();
sensor.initialize(context);

// 获取当前指标
final metrics = sensor.currentMetrics;
print('设备类型: ${metrics.deviceType}');
print('最优列数: ${metrics.optimalColumns}');
```

### 3. ContentAnalyzer

内容分析器，分析列表内容的特征，为布局决策提供依据。

**分析维度：**
- 平均标题长度
- 标题长度方差
- 内容类型混杂度
- 宽高比变化度

**使用方式：**

```dart
class VideoContentExtractor implements ContentExtractor<VideoItem> {
  @override
  String extractTitle(VideoItem item) => item.title;
  
  @override
  String extractType(VideoItem item) => item.type;
  
  @override
  double extractAspectRatio(VideoItem item) => 16 / 10;
  
  @override
  double estimateAverageHeight(List<VideoItem> items) => 200;
}

final profile = ContentProfile.analyze(videos, VideoContentExtractor());
```

### 4. LayoutStrategy

布局策略引擎，基于多种因素推荐最优布局。

**决策因素：**
- 屏幕指标 (ScreenMetrics)
- 浏览意图 (BrowseIntent)
- 内容特征 (ContentProfile)
- 用户偏好 (LayoutPreference)

**使用方式：**

```dart
// 推荐布局
final config = LayoutStrategyEngine.recommendForScreen(metrics);

// 基于意图推荐
final config = LayoutStrategyEngine.recommendForIntent(
  BrowseIntent.discover,
  metrics,
  contentProfile: profile,
);

// 创建自适应策略
final strategy = LayoutStrategyEngine.createAdaptiveStrategy(
  defaultIntent: BrowseIntent.discover,
  preferences: {
    BrowseIntent.search: LayoutPreference(preferredType: LayoutType.list),
  },
);
```

### 5. ResponsiveLayoutBuilder

响应式布局构建器，根据配置自动渲染对应布局。

**特性：**
- 支持 List/Grid/Waterfall/Hybrid 四种布局
- 自动处理加载更多
- 支持下拉刷新
- 支持自定义头部/底部

**使用方式：**

```dart
ResponsiveLayoutBuilder(
  intent: BrowseIntent.discover,
  itemCount: videos.length,
  itemBuilder: (context, index) => VideoCard(video: videos[index]),
  header: SearchBar(),
  footer: LoadMoreIndicator(),
  onRefresh: () async => await loadData(),
  onLoadMore: () => loadMore(),
)
```

## 类型系统

### LayoutType

```dart
enum LayoutType {
  list,      // 单列列表
  grid,      // 均匀网格
  waterfall, // 瀑布流
  hybrid,    // 混合布局
}
```

### BrowseIntent

```dart
enum BrowseIntent {
  search,          // 搜索特定内容
  discover,        // 发现新内容
  review,          // 回顾已知内容
  browseDynamics,  // 浏览动态
}
```

### DeviceType

```dart
enum DeviceType {
  phonePortrait,     // 手机竖屏
  phoneLandscape,    // 手机横屏
  smallTablet,       // 小平板
  largeTablet,       // 大平板
  foldableFolded,    // 折叠屏折叠
  foldableUnfolded,  // 折叠屏展开
}
```

### InformationDensity

```dart
enum InformationDensity {
  minimal,  // 极简（仅封面+标题）
  low,      // 低密度
  normal,   // 正常
  high,     // 高密度
  maximum,  // 最大（展示所有信息）
}
```

## 配置参数

### LayoutConstants

```dart
abstract final class LayoutConstants {
  static const double baseCardWidth = 180.0;   // 基础卡片宽度
  static const double maxCardWidth = 280.0;    // 最大卡片宽度
  static const double minCardWidth = 160.0;    // 最小卡片宽度
  static const double aspectRatio = 16 / 10;   // 默认宽高比
  static const double gridSpacing = 8.0;       // 网格间距
  static const double listSpacing = 12.0;      // 列表间距
  
  // 设备断点
  static const double phoneBreakpoint = 600;
  static const double tabletBreakpoint = 840;
  static const double desktopBreakpoint = 1200;
}
```

### LayoutConfig

```dart
@immutable
class LayoutConfig {
  final LayoutType type;           // 布局类型
  final int columns;               // 列数
  final double spacing;            // 间距
  final double cardAspectRatio;    // 卡片宽高比
  final bool useSidebar;           // 是否使用侧边栏
  final InformationDensity density; // 信息密度
  final ScrollPhysics? physics;    // 滚动物理效果
}
```

## 使用示例

### 基础使用

```dart
class VideoListPage extends StatelessWidget {
  final List<Video> videos;
  
  const VideoListPage({super.key, required this.videos});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频列表')),
      body: ResponsiveLayoutBuilder(
        intent: BrowseIntent.discover,
        itemCount: videos.length,
        itemBuilder: (context, index) {
          return ResponsiveVideoCard(
            title: videos[index].title,
            coverUrl: videos[index].cover,
            upName: videos[index].upName,
            duration: videos[index].duration,
            viewCount: videos[index].viewCount,
            onTap: () => playVideo(videos[index]),
          );
        },
        onLoadMore: () => loadMoreVideos(),
        onRefresh: () async => await refreshVideos(),
      ),
    );
  }
}
```

### 高级使用：内容感知布局

```dart
class SmartVideoListPage extends StatefulWidget {
  @override
  State<SmartVideoListPage> createState() => _SmartVideoListPageState();
}

class _SmartVideoListPageState extends State<SmartVideoListPage> {
  final LayoutOrchestrator _orchestrator = LayoutOrchestrator();
  List<Video> _videos = [];
  
  @override
  void initState() {
    super.initState();
    _loadVideos();
  }
  
  Future<void> _loadVideos() async {
    final videos = await fetchVideos();
    setState(() => _videos = videos);
    
    // 分析内容并更新布局
    _orchestrator.updateContentProfile(
      videos,
      VideoContentExtractor(),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutConfigProvider(
      config: _orchestrator.currentConfig ?? LayoutConfig.grid(columns: 2),
      child: ResponsiveLayoutBuilder(
        intent: BrowseIntent.discover,
        itemCount: _videos.length,
        itemBuilder: (context, index) => VideoCard(video: _videos[index]),
      ),
    );
  }
}
```

### 自定义布局策略

```dart
class CustomLayoutStrategy {
  static LayoutConfig recommendForMyApp(
    ScreenMetrics metrics,
    ContentProfile? profile,
  ) {
    // 自定义逻辑
    if (profile?.averageTitleLength > 50) {
      // 标题很长，使用单列
      return LayoutConfig.list(density: InformationDensity.high);
    }
    
    // 默认使用网格
    return LayoutConfig.grid(
      columns: metrics.optimalColumns,
      useSidebar: metrics.isTablet,
    );
  }
}
```

### 侧边栏布局

```dart
class TabletHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final config = LayoutConfigProvider.of(context);
    
    return SidebarLayout(
      useSidebar: config?.useSidebar ?? false,
      sidebar: NavigationSidebar(),
      content: ResponsiveLayoutBuilder(
        intent: BrowseIntent.discover,
        itemCount: videos.length,
        itemBuilder: (context, index) => VideoCard(video: videos[index]),
      ),
    );
  }
}
```

## 性能优化

### 1. 列表项复用

```dart
ResponsiveLayoutBuilder(
  itemBuilder: (context, index) {
    // 使用 const 构造函数
    return const VideoCard(...);
  },
)
```

### 2. 重绘边界

```dart
class VideoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Card(...),
    );
  }
}
```

### 3. 延迟加载

```dart
ResponsiveLayoutBuilder(
  // 只加载可视区域 + 200px 缓存
  cacheExtent: 200,
  itemBuilder: ...,)
```

## 最佳实践

### 1. 意图明确

为每个页面选择合适的 `BrowseIntent`：

- **搜索页面** → `BrowseIntent.search`
- **首页推荐** → `BrowseIntent.discover`
- **收藏管理** → `BrowseIntent.review`
- **动态页面** → `BrowseIntent.browseDynamics`

### 2. 内容分析

对于内容差异大的页面，实现 `ContentExtractor`：

```dart
class MyContentExtractor implements ContentExtractor<MyItem> {
  @override
  String extractTitle(item) => item.title;
  
  @override
  String extractType(item) => item.contentType;
  
  @override
  double extractAspectRatio(item) {
    // 根据图片/视频内容返回不同比例
    return item.hasImage ? 1.0 : 16 / 10;
  }
  
  @override
  double estimateAverageHeight(items) {
    // 估算平均高度
    return items.isEmpty ? 200 : items.map((i) => i.estimatedHeight).average();
  }
}
```

### 3. 用户偏好

允许用户自定义布局：

```dart
// 保存用户偏好
PrefHelper.setLayoutPreference(
  BrowseIntent.discover,
  LayoutPreference(
    preferredType: LayoutType.waterfall,
    preferredColumns: 3,
  ),
);

// 应用偏好
orchestrator.setPreference(
  BrowseIntent.discover,
  PrefHelper.getLayoutPreference(BrowseIntent.discover),
);
```

### 4. 错误处理

```dart
ResponsiveLayoutBuilder(
  itemCount: videos.length,
  itemBuilder: (context, index) {
    try {
      return VideoCard(video: videos[index]);
    } catch (e) {
      // 返回占位符
      return ErrorCard(error: e);
    }
  },
)
```

## 故障排查

### 布局不更新

检查是否正确监听 orchestrator：

```dart
@override
void initState() {
  super.initState();
  orchestrator.addListener(() => setState(() {}));
}
```

### 列数不正确

检查 `ScreenMetrics` 是否正确初始化：

```dart
// 确保在布局完成后初始化
WidgetsBinding.instance.addPostFrameCallback((_) {
  orchestrator.initialize(context: context, ...);
});
```

### 瀑布流不工作

确保已添加 `waterfall_flow` 依赖：

```yaml
dependencies:
  waterfall_flow: ^3.x.x
```

## 路线图

### v1.0

- [x] 基础架构
- [x] Grid/List 布局
- [x] 设备感知
- [x] 内容分析

### v1.1

- [ ] 完整瀑布流支持
- [ ] 混合布局
- [ ] 动画过渡

### v1.2

- [ ] AI 驱动的布局推荐
- [ ] 手势切换布局
- [ ] 实时预览

### v2.0

- [ ] 桌面端优化
- [ ] Web 支持
- [ ] 性能监控

## 参考

- [Material Design 布局指南](https://material.io/design/layout/understanding-layout.html)
- [Flutter 响应式设计](https://flutter.dev/docs/development/ui/layout/adaptive-responsive)
- [Foldable 设备适配](https://developer.android.com/guide/topics/large-screens/learn-about-foldables)
