# 响应式布局快速参考

## 目录
1. [5分钟快速开始](#5分钟快速开始)
2. [常用模式](#常用模式)
3. [配置参数速查](#配置参数速查)
4. [故障排查](#故障排查)
5. [API 速查](#api速查)

---

## 5分钟快速开始

### 步骤 1: 导入包

```dart
import 'package:PiliPro/common/layout/layout_orchestrator.dart';
import 'package:PiliPro/common/layout/layout_types.dart';
import 'package:PiliPro/common/layout/responsive_widgets.dart';
```

### 步骤 2: 包装你的列表

```dart
class MyPage extends StatelessWidget {
  final List videos = [...];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveLayoutBuilder(
        intent: BrowseIntent.discover,
        itemCount: videos.length,
        itemBuilder: (context, index) => MyVideoCard(video: videos[index]),
      ),
    );
  }
}
```

完成！系统会自动根据屏幕尺寸选择最佳布局。

---

## 常用模式

### 模式 1: 基础网格布局

```dart
ResponsiveLayoutBuilder(
  intent: BrowseIntent.discover,
  itemCount: videos.length,
  itemBuilder: (context, index) => VideoCard(video: videos[index]),
)
```

### 模式 2: 单列列表（搜索页面）

```dart
ResponsiveLayoutBuilder(
  intent: BrowseIntent.search,  // 搜索意图自动使用单列
  itemCount: results.length,
  itemBuilder: (context, index) => ListItem(result: results[index]),
)
```

### 模式 3: 带刷新和加载更多

```dart
ResponsiveLayoutBuilder(
  intent: BrowseIntent.discover,
  itemCount: videos.length,
  itemBuilder: (context, index) => VideoCard(video: videos[index]),
  onRefresh: () async => await loadData(),
  onLoadMore: () => loadMore(),
)
```

### 模式 4: 骨架屏加载

```dart
isLoading
  ? ResponsiveSkeleton(itemCount: 12)
  : ResponsiveLayoutBuilder(...)
```

### 模式 5: 内容感知布局

```dart
final orchestrator = LayoutOrchestrator();
orchestrator.initialize(context: context, defaultIntent: BrowseIntent.discover);
orchestrator.updateContentProfile(videos, VideoContentExtractor());

return LayoutConfigProvider(
  config: orchestrator.currentConfig!,
  child: ResponsiveLayoutBuilder(...),
);
```

---

## 配置参数速查

### LayoutType

| 值 | 说明 | 适用场景 |
|----|------|----------|
| `LayoutType.grid` | 均匀网格 | 大多数视频列表 |
| `LayoutType.list` | 单列列表 | 搜索、详细浏览 |
| `LayoutType.waterfall` | 瀑布流 | 动态、内容高度不一 |
| `LayoutType.hybrid` | 混合 | 特殊需求 |

### BrowseIntent

| 值 | 默认布局 | 特点 |
|----|----------|------|
| `BrowseIntent.discover` | Grid/Waterfall | 视觉优先 |
| `BrowseIntent.search` | List | 信息密度高 |
| `BrowseIntent.review` | Grid(紧凑) | 高效浏览 |
| `BrowseIntent.browseDynamics` | Waterfall | 内容多样 |

### DeviceType

| 值 | 宽度范围 | 默认列数 |
|----|----------|----------|
| `phonePortrait` | < 600dp | 2 |
| `phoneLandscape` | 600-840dp | 3 |
| `smallTablet` | 600-840dp | 3 |
| `largeTablet` | > 840dp | 4 |

### InformationDensity

| 值 | 标题行数 | 统计信息 | UP主名 |
|----|----------|----------|--------|
| `minimal` | 1 | 无 | 无 |
| `low` | 1 | 无 | 有 |
| `normal` | 2 | 有 | 有 |
| `high` | 2 | 有 | 有+徽章 |
| `maximum` | 2 | 全 | 全 |

---

## 故障排查

### 问题 1: 布局不响应屏幕变化

**症状**: 旋转屏幕后布局不变

**解决方案**:
```dart
// 确保初始化时传入了 context
orchestrator.initialize(context: context, ...);

// 确保监听了变化
orchestrator.addListener(() => setState(() {}));
```

### 问题 2: 列数不符合预期

**症状**: 手机显示 1 列，或平板显示太多列

**检查**:
```dart
// 打印调试信息
final metrics = ScreenMetrics.fromContext(context);
print('宽度: ${metrics.width}');
print('设备类型: ${metrics.deviceType}');
print('最优列数: ${metrics.optimalColumns}');
```

### 问题 3: 瀑布流不起作用

**症状**: 设置为 waterfall 但显示为网格

**原因**: 需要引入 waterfall_flow 包

**解决方案**:
```yaml
# pubspec.yaml
dependencies:
  waterfall_flow: ^3.x.x
```

### 问题 4: 内容截断或溢出

**症状**: 卡片内容显示不全

**解决方案**:
```dart
// 使用 ResponsiveVideoCard，自动适应
ResponsiveVideoCard(
  title: video.title,
  // 会自动根据布局密度调整显示内容
)
```

### 问题 5: 性能问题

**症状**: 滚动卡顿

**优化**:
```dart
// 1. 使用 const 构造函数
itemBuilder: (context, index) => const VideoCard(...)

// 2. 添加 RepaintBoundary
RepaintBoundary(child: VideoCard(...))

// 3. 设置缓存区域
ResponsiveLayoutBuilder(
  cacheExtent: 200,  // 可视区域外缓存 200px
  ...
)
```

---

## API 速查

### ResponsiveLayoutBuilder

| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `intent` | `BrowseIntent` | ✓ | 浏览意图 |
| `itemCount` | `int` | ✓ | 项目数量 |
| `itemBuilder` | `IndexedWidgetBuilder` | ✓ | 项目构建器 |
| `header` | `Widget?` | ✗ | 头部 |
| `footer` | `Widget?` | ✗ | 底部 |
| `onRefresh` | `Future<void> Function()?` | ✗ | 下拉刷新回调 |
| `onLoadMore` | `VoidCallback?` | ✗ | 加载更多回调 |
| `scrollController` | `ScrollController?` | ✗ | 滚动控制器 |
| `padding` | `EdgeInsets` | ✗ | 内边距 |

### LayoutOrchestrator

| 方法 | 说明 |
|------|------|
| `initialize()` | 初始化 |
| `setIntent()` | 更改浏览意图 |
| `updateContentProfile()` | 更新内容分析 |
| `setPreference()` | 设置用户偏好 |
| `refresh()` | 强制刷新布局 |
| `addListener()` | 添加监听器 |
| `removeListener()` | 移除监听器 |
| `dispose()` | 清理资源 |

### LayoutConfig

| 属性 | 类型 | 说明 |
|------|------|------|
| `type` | `LayoutType` | 布局类型 |
| `columns` | `int` | 列数 |
| `spacing` | `double` | 间距 |
| `cardAspectRatio` | `double` | 卡片宽高比 |
| `useSidebar` | `bool` | 是否使用侧边栏 |
| `density` | `InformationDensity` | 信息密度 |

### ScreenMetrics

| 属性 | 类型 | 说明 |
|------|------|------|
| `width` | `double` | 屏幕宽度 |
| `height` | `double` | 屏幕高度 |
| `deviceType` | `DeviceType` | 设备类型 |
| `isTablet` | `bool` | 是否为平板 |
| `optimalColumns` | `int` | 最优列数 |
| `maxColumns` | `int` | 最大列数 |

### LayoutStrategyEngine

| 方法 | 说明 |
|------|------|
| `recommendForScreen()` | 基于屏幕推荐布局 |
| `recommendForIntent()` | 基于意图推荐布局 |
| `optimizeForContent()` | 基于内容优化布局 |
| `createAdaptiveStrategy()` | 创建自适应策略 |

---

## 最佳实践速查

✅ **应该做的**
- 为每个页面选择合适的 `BrowseIntent`
- 使用 `ResponsiveVideoCard` 自动适配
- 使用 `ResponsiveSkeleton` 处理加载状态
- 平板使用 `SidebarLayout`
- 为内容差异大的页面实现 `ContentExtractor`

❌ **不应该做的**
- 硬编码列数
- 忽略横竖屏切换
- 在所有页面使用相同的意图
- 忘记监听 orchestrator 变化
- 忽视平板设备

---

## 尺寸参考

### 设备断点

```dart
// 手机
if (width < 600) return 2;  // 2列

// 小平板
if (width < 840) return 3;  // 3列

// 大平板
if (width < 1200) return 4; // 4列

// 桌面
return 5;  // 5列
```

### 卡片尺寸

```dart
// 最小卡片宽度
minCardWidth = 160.0;

// 基础卡片宽度
baseCardWidth = 180.0;

// 最大卡片宽度
maxCardWidth = 280.0;

// 默认宽高比
aspectRatio = 16 / 10;
```

### 间距

```dart
// 网格间距
gridSpacing = 8.0;

// 列表间距
listSpacing = 12.0;

// 安全边距
safeSpace = 12.0;
```

---

## 相关文件

| 文件 | 说明 |
|------|------|
| `layout_types.dart` | 类型定义 |
| `layout_strategy.dart` | 策略引擎 |
| `layout_orchestrator.dart` | 协调器 |
| `responsive_widgets.dart` | 响应式组件 |
| `examples.dart` | 完整示例 |
| `ARCHITECTURE.md` | 架构文档 |
| `MIGRATION_GUIDE.md` | 迁移指南 |

---

## 获取帮助

- 📖 详细文档: [ARCHITECTURE.md](./ARCHITECTURE.md)
- 🚀 迁移指南: [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)
- 💡 代码示例: [examples.dart](./examples.dart)

---

*最后更新: 2024年*
