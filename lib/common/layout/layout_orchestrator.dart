import 'package:PiliPro/common/layout/layout_strategy.dart';
import 'package:PiliPro/common/layout/layout_types.dart';
import 'package:flutter/material.dart';

/// 布局协调器 - 中央控制器
///
/// 职责：
/// 1. 监听设备和屏幕变化
/// 2. 协调内容分析和布局决策
/// 3. 管理用户偏好
/// 4. 触发布局更新
class LayoutOrchestrator extends ChangeNotifier {
  static LayoutOrchestrator? _instance;

  factory LayoutOrchestrator() {
    _instance ??= LayoutOrchestrator._internal();
    return _instance!;
  }

  LayoutOrchestrator._internal();

  final DeviceSensor _deviceSensor = DeviceSensor();
  AdaptiveLayoutStrategy? _strategy;
  LayoutConfig? _currentConfig;
  BrowseIntent? _currentIntent;
  ContentProfile? _currentContentProfile;

  // Getters
  DeviceSensor get deviceSensor => _deviceSensor;
  LayoutConfig? get currentConfig => _currentConfig;
  BrowseIntent? get currentIntent => _currentIntent;
  bool get isInitialized => _currentConfig != null;

  /// 初始化协调器
  void initialize({
    required BuildContext context,
    required BrowseIntent defaultIntent,
    Map<BrowseIntent, LayoutPreference>? preferences,
  }) {
    _deviceSensor.initialize(context);
    _strategy = LayoutStrategyEngine.createAdaptiveStrategy(
      defaultIntent: defaultIntent,
      preferences: preferences,
    );
    _currentIntent = defaultIntent;

    // 监听设备变化
    _deviceSensor.addListener(_onDeviceChanged);

    // 初始计算
    _recalculateConfig();
  }

  /// 处理设备变化
  void _onDeviceChanged() {
    _recalculateConfig();
  }

  /// 重新计算布局配置
  void _recalculateConfig() {
    if (_strategy == null || _deviceSensor.currentMetrics == null) return;

    final newConfig = _strategy!.resolve(
      _deviceSensor.currentMetrics!,
      intent: _currentIntent,
      contentProfile: _currentContentProfile,
    );

    if (_currentConfig?.type != newConfig.type ||
        _currentConfig?.columns != newConfig.columns ||
        _currentConfig?.useSidebar != newConfig.useSidebar) {
      _currentConfig = newConfig;
      notifyListeners();
    }
  }

  /// 更新浏览意图
  void setIntent(BrowseIntent intent) {
    if (_currentIntent == intent) return;
    _currentIntent = intent;
    _recalculateConfig();
  }

  /// 更新内容特征
  void updateContentProfile<T>(
    List<T> items,
    ContentExtractor<T> extractor,
  ) {
    _currentContentProfile = ContentProfile.analyze(items, extractor);
    _recalculateConfig();
  }

  /// 设置用户偏好
  void setPreference(BrowseIntent intent, LayoutPreference preference) {
    _strategy?.preferences[intent] = preference;
    if (_currentIntent == intent) {
      _recalculateConfig();
    }
  }

  /// 强制刷新布局
  void refresh() {
    _recalculateConfig();
  }

  /// 清理资源
  void dispose() {
    _deviceSensor.removeListener(_onDeviceChanged);
    _deviceSensor.dispose();
    _instance = null;
    super.dispose();
  }
}

/// 响应式布局构建器
///
/// 使用示例：
/// ```dart
/// ResponsiveLayoutBuilder(
///   intent: BrowseIntent.discover,
///   itemCount: videos.length,///   itemBuilder: (context, index) => VideoCard(video: videos[index]),
/// )
/// ```
class ResponsiveLayoutBuilder extends StatefulWidget {
  final BrowseIntent intent;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? header;
  final Widget? footer;
  final ScrollController? scrollController;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onLoadMore;
  final EdgeInsets padding;

  const ResponsiveLayoutBuilder({
    super.key,
    required this.intent,
    required this.itemCount,
    required this.itemBuilder,
    this.header,
    this.footer,
    this.scrollController,
    this.onRefresh,
    this.onLoadMore,
    this.padding = const EdgeInsets.all(8),
  });

  @override
  State<ResponsiveLayoutBuilder> createState() =>
      _ResponsiveLayoutBuilderState();
}

class _ResponsiveLayoutBuilderState extends State<ResponsiveLayoutBuilder> {
  late final LayoutOrchestrator _orchestrator;

  @override
  void initState() {
    super.initState();
    _orchestrator = LayoutOrchestrator();
    _orchestrator.initialize(
      context: context,
      defaultIntent: widget.intent,
    );
    _orchestrator.addListener(_onLayoutChanged);
  }

  @override
  void didUpdateWidget(ResponsiveLayoutBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.intent != oldWidget.intent) {
      _orchestrator.setIntent(widget.intent);
    }
  }

  void _onLayoutChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _orchestrator.removeListener(_onLayoutChanged);
    _orchestrator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _orchestrator.currentConfig;

    if (config == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return _LayoutRenderer(
      config: config,
      itemCount: widget.itemCount,
      itemBuilder: widget.itemBuilder,
      header: widget.header,
      footer: widget.footer,
      scrollController: widget.scrollController,
      onRefresh: widget.onRefresh,
      onLoadMore: widget.onLoadMore,
      padding: widget.padding,
    );
  }
}

/// 布局渲染器 - 根据配置渲染对应布局
class _LayoutRenderer extends StatelessWidget {
  final LayoutConfig config;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? header;
  final Widget? footer;
  final ScrollController? scrollController;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onLoadMore;
  final EdgeInsets padding;

  const _LayoutRenderer({
    required this.config,
    required this.itemCount,
    required this.itemBuilder,
    this.header,
    this.footer,
    this.scrollController,
    this.onRefresh,
    this.onLoadMore,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = switch (config.type) {
      LayoutType.list => _buildList(),
      LayoutType.grid => _buildGrid(),
      LayoutType.waterfall => _buildWaterfall(),
      LayoutType.hybrid => _buildHybrid(),
    };

    if (onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: onRefresh!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildList() {
    return CustomScrollView(
      controller: scrollController,
      physics: config.physics ?? const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        SliverPadding(
          padding: padding,
          sliver: SliverList.builder(
            itemCount: itemCount + (onLoadMore != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == itemCount - 1 && onLoadMore != null) {
                onLoadMore!();
              }
              if (index >= itemCount) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              return Padding(
                padding: EdgeInsets.only(bottom: config.spacing),
                child: itemBuilder(context, index),
              );
            },
          ),
        ),
        if (footer != null) SliverToBoxAdapter(child: footer),
      ],
    );
  }

  Widget _buildGrid() {
    return CustomScrollView(
      controller: scrollController,
      physics: config.physics ?? const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        SliverPadding(
          padding: padding,
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: config.columns,
              mainAxisSpacing: config.spacing,
              crossAxisSpacing: config.spacing,
              childAspectRatio: config.cardAspectRatio,
            ),
            itemCount: itemCount + (onLoadMore != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == itemCount - 1 && onLoadMore != null) {
                onLoadMore!();
              }
              if (index >= itemCount) {
                return const Center(child: CircularProgressIndicator());
              }
              return itemBuilder(context, index);
            },
          ),
        ),
        if (footer != null) SliverToBoxAdapter(child: footer),
      ],
    );
  }

  Widget _buildWaterfall() {
    // 瀑布流需要使用 waterfall_flow 包
    // 这里提供基础结构，实际实现需要引入包
    return CustomScrollView(
      controller: scrollController,
      physics: config.physics ?? const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        SliverPadding(
          padding: padding,
          sliver: SliverGrid.builder(
            // 临时使用网格布局，实际应使用瀑布流
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: LayoutConstants.maxCardWidth,
              mainAxisSpacing: config.spacing,
              crossAxisSpacing: config.spacing,
            ),
            itemCount: itemCount + (onLoadMore != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == itemCount - 1 && onLoadMore != null) {
                onLoadMore!();
              }
              if (index >= itemCount) {
                return const Center(child: CircularProgressIndicator());
              }
              return itemBuilder(context, index);
            },
          ),
        ),
        if (footer != null) SliverToBoxAdapter(child: footer),
      ],
    );
  }

  Widget _buildHybrid() {
    // 混合布局：首屏瀑布流，后续网格
    // 这里简化处理，实际实现更复杂
    return _buildGrid();
  }
}

/// 侧边栏布局包装器
class SidebarLayout extends StatelessWidget {
  final bool useSidebar;
  final Widget sidebar;
  final Widget content;
  final double sidebarWidth;

  const SidebarLayout({
    super.key,
    required this.useSidebar,
    required this.sidebar,
    required this.content,
    this.sidebarWidth = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (!useSidebar) {
      return content;
    }

    return Row(
      children: [
        SizedBox(
          width: sidebarWidth,
          child: sidebar,
        ),
        Expanded(child: content),
      ],
    );
  }
}

/// 布局配置提供者
/// 用于在 widget 树中共享布局配置
class LayoutConfigProvider extends InheritedWidget {
  final LayoutConfig config;

  const LayoutConfigProvider({
    super.key,
    required this.config,
    required super.child,
  });

  static LayoutConfig? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LayoutConfigProvider>()
        ?.config;
  }

  @override
  bool updateShouldNotify(LayoutConfigProvider oldWidget) {
    return config.type != oldWidget.config.type ||
        config.columns != oldWidget.config.columns;
  }
}
