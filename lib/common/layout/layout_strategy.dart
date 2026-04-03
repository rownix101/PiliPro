import 'dart:math' as math;

import 'package:PiliPro/common/layout/layout_types.dart';
import 'package:flutter/material.dart';

/// 设备传感器 - 监听设备和屏幕变化
class DeviceSensor extends ChangeNotifier {
  ScreenMetrics? _currentMetrics;
  bool _isFoldable = false;
  bool _isFolded = false;

  ScreenMetrics? get currentMetrics => _currentMetrics;
  bool get isFoldable => _isFoldable;
  bool get isFolded => _isFolded && _isFoldable;

  /// 从 BuildContext 初始化
  void initialize(BuildContext context) {
    _updateMetrics(context);
  }

  /// 更新屏幕指标
  void _updateMetrics(BuildContext context) {
    final newMetrics = ScreenMetrics.fromContext(context);

    // 检测折叠屏状态（这里使用启发式方法）
    _detectFoldableState(newMetrics);

    if (_currentMetrics == null ||
        _currentMetrics!.size != newMetrics.size ||
        _currentMetrics!.orientation != newMetrics.orientation) {
      _currentMetrics = newMetrics;
      notifyListeners();
    }
  }

  /// 检测折叠屏状态
  void _detectFoldableState(ScreenMetrics metrics) {
    // 启发式检测：如果屏幕比例在折叠和展开之间变化
    final aspectRatio = metrics.width / metrics.height;

    // 如果屏幕宽度接近折叠屏的折叠状态
    if (_isFoldable) {
      // 已确定是折叠屏，检测展开/折叠状态
      _isFolded = metrics.width < LayoutConstants.foldableUnfoldedWidth;
    } else {
      // 尝试检测是否为折叠屏
      // 折叠屏特征：可以非常宽（展开）或非常窄（折叠）
      if (metrics.width > LayoutConstants.foldableUnfoldedWidth ||
          (metrics.width > LayoutConstants.foldableFoldedWidth &&
              metrics.width < LayoutConstants.phoneBreakpoint)) {
        _isFoldable = true;
        _isFolded = metrics.width < LayoutConstants.foldableUnfoldedWidth;
      }
    }

    // 更新设备类型
    if (_isFoldable) {
      _currentMetrics = _currentMetrics?.copyWith(
        deviceType: _isFolded
            ? DeviceType.foldableFolded
            : DeviceType.foldableUnfolded,
      );
    }
  }

  /// 处理屏幕尺寸变化
  void onScreenChanged(BuildContext context) {
    _updateMetrics(context);
  }
}

/// 布局策略决策引擎
class LayoutStrategyEngine {
  /// 基于屏幕指标推荐布局配置
  static LayoutConfig recommendForScreen(ScreenMetrics metrics) {
    switch (metrics.deviceType) {
      case DeviceType.phonePortrait:
        return LayoutConfig.grid(
          columns: 2,
          spacing: LayoutConstants.gridSpacing,
          aspectRatio: LayoutConstants.aspectRatio,
        );

      case DeviceType.phoneLandscape:
        return LayoutConfig.grid(
          columns: 3,
          spacing: LayoutConstants.gridSpacing * 1.5,
          aspectRatio: 16 / 9,
        );

      case DeviceType.smallTablet:
        return LayoutConfig.grid(
          columns: 3,
          spacing: LayoutConstants.gridSpacing * 1.5,
          useSidebar: true,
        );

      case DeviceType.largeTablet:
        return LayoutConfig.grid(
          columns: 4,
          spacing: LayoutConstants.gridSpacing * 2,
          useSidebar: true,
        );

      case DeviceType.foldableFolded:
        return LayoutConfig.grid(
          columns: 2,
          spacing: LayoutConstants.gridSpacing,
        );

      case DeviceType.foldableUnfolded:
        return LayoutConfig.grid(
          columns: 4,
          spacing: LayoutConstants.gridSpacing * 1.5,
          useSidebar: true,
        );
    }
  }

  /// 基于浏览意图推荐布局
  static LayoutConfig recommendForIntent(
    BrowseIntent intent,
    ScreenMetrics metrics, {
    ContentProfile? contentProfile,
  }) {
    switch (intent) {
      case BrowseIntent.search:
        // 搜索场景：单列列表，高信息密度
        return LayoutConfig.list(
          spacing: LayoutConstants.listSpacing,
          density: InformationDensity.high,
        );

      case BrowseIntent.discover:
        // 发现场景：基于屏幕的网格或瀑布流
        if (contentProfile?.hasVariableAspectRatios == true ||
            (contentProfile?.averageTitleLength ?? 0) > 35) {
          // 内容高度不一致或标题较长，使用瀑布流
          return LayoutConfig.waterfall(
            columns: metrics.optimalColumns,
            spacing: LayoutConstants.gridSpacing,
            useSidebar: metrics.isTablet,
          );
        }
        return LayoutConfig.grid(
          columns: metrics.optimalColumns,
          spacing: LayoutConstants.gridSpacing,
          useSidebar: metrics.isTablet,
        );

      case BrowseIntent.review:
        // 回顾场景：紧凑网格
        return LayoutConfig.grid(
          columns: metrics.maxColumns,
          spacing: LayoutConstants.gridSpacing * 0.5,
          aspectRatio: 16 / 9,
        );

      case BrowseIntent.browseDynamics:
        // 动态场景：默认瀑布流，但允许用户切换
        return LayoutConfig.waterfall(
          columns: math.min(metrics.optimalColumns, 2),
          spacing: LayoutConstants.gridSpacing,
          useSidebar: false,
        );
    }
  }

  /// 基于内容特征优化布局
  static LayoutConfig optimizeForContent(
    LayoutConfig baseConfig,
    ContentProfile profile,
    ScreenMetrics metrics,
  ) {
    var config = baseConfig;

    // 根据标题长度调整信息密度
    if (profile.averageTitleLength > 40) {
      config = config.copyWith(
        informationDensity: InformationDensity.high,
      );
    } else if (profile.averageTitleLength < 20) {
      config = config.copyWith(
        informationDensity: InformationDensity.low,
      );
    }

    // 如果标题长度差异大，考虑使用瀑布流
    if (profile.titleLengthVariance > 100 && config.type == LayoutType.grid) {
      config = LayoutConfig.waterfall(
        columns: config.columns,
        spacing: config.spacing,
        useSidebar: config.useSidebar,
      );
    }

    // 验证配置有效性
    if (!config.isValidFor(metrics)) {
      config = _adjustToValidConfig(config, metrics);
    }

    return config;
  }

  /// 调整配置使其有效
  static LayoutConfig _adjustToValidConfig(
    LayoutConfig config,
    ScreenMetrics metrics,
  ) {
    final cardWidth = config.calculateCardWidth(metrics.width);

    if (cardWidth < LayoutConstants.minCardWidth) {
      // 卡片太小，减少列数
      final maxColumns =
          (metrics.width / (LayoutConstants.minCardWidth + config.spacing))
              .floor()
              .clamp(1, 6);
      return config.copyWith(columns: maxColumns);
    }

    if (cardWidth > LayoutConstants.maxCardWidth) {
      // 卡片太大，增加列数或增加间距
      final minColumns =
          (metrics.width / (LayoutConstants.maxCardWidth + config.spacing))
              .ceil()
              .clamp(1, 6);
      return config.copyWith(columns: minColumns);
    }

    return config;
  }

  /// 生成自适应布局策略
  static AdaptiveLayoutStrategy createAdaptiveStrategy({
    required BrowseIntent defaultIntent,
    Map<BrowseIntent, LayoutPreference>? preferences,
  }) {
    return AdaptiveLayoutStrategy(
      defaultIntent: defaultIntent,
      preferences: preferences ?? {},
    );
  }
}

/// 布局偏好设置
@immutable
class LayoutPreference {
  final LayoutType? preferredType;
  final int? preferredColumns;
  final bool? preferSidebar;
  final InformationDensity? preferredDensity;

  const LayoutPreference({
    this.preferredType,
    this.preferredColumns,
    this.preferSidebar,
    this.preferredDensity,
  });

  /// 应用用户偏好到布局配置
  LayoutConfig applyTo(LayoutConfig config) {
    return config.copyWith(
      type: preferredType ?? config.type,
      columns: preferredColumns ?? config.columns,
      useSidebar: preferSidebar ?? config.useSidebar,
      informationDensity: preferredDensity ?? config.informationDensity,
    );
  }
}

/// 自适应布局策略
class AdaptiveLayoutStrategy {
  final BrowseIntent defaultIntent;
  final Map<BrowseIntent, LayoutPreference> preferences;

  AdaptiveLayoutStrategy({
    required this.defaultIntent,
    required this.preferences,
  });

  /// 计算最终布局配置
  LayoutConfig resolve(
    ScreenMetrics metrics, {
    BrowseIntent? intent,
    ContentProfile? contentProfile,
  }) {
    final effectiveIntent = intent ?? defaultIntent;

    // 1. 基于意图获取基础配置
    var config = LayoutStrategyEngine.recommendForIntent(
      effectiveIntent,
      metrics,
      contentProfile: contentProfile,
    );

    // 2. 基于内容优化
    if (contentProfile != null) {
      config = LayoutStrategyEngine.optimizeForContent(
        config,
        contentProfile,
        metrics,
      );
    }

    // 3. 应用用户偏好
    final preference = preferences[effectiveIntent];
    if (preference != null) {
      config = preference.applyTo(config);
    }

    // 4. 最终验证
    if (!config.isValidFor(metrics)) {
      config = LayoutStrategyEngine._adjustToValidConfig(config, metrics);
    }

    return config;
  }
}
