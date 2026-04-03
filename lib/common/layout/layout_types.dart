import 'package:flutter/material.dart';

/// 布局系统核心常量
abstract final class LayoutConstants {
  // 基础卡片宽度（单列时的目标宽度）
  static const double baseCardWidth = 180.0;

  // 最大卡片宽度（防止大屏卡片过大）
  static const double maxCardWidth = 280.0;

  // 最小卡片宽度（保证可点击性）
  static const double minCardWidth = 160.0;

  // 基础宽高比
  static const double aspectRatio = 16 / 10;

  // 标准间距
  static const double gridSpacing = 8.0;
  static const double listSpacing = 12.0;

  // 设备类型断点
  static const double phoneBreakpoint = 600;
  static const double tabletBreakpoint = 840;
  static const double desktopBreakpoint = 1200;

  // 折叠屏特殊处理
  static const double foldableFoldedWidth = 400;
  static const double foldableUnfoldedWidth = 700;
}

/// 布局类型枚举
enum LayoutType {
  /// 单列列表 - 适合详细浏览
  list,

  /// 均匀网格 - 适合快速浏览
  grid,

  /// 瀑布流 - 适合内容高度不一致的场景
  waterfall,

  /// 混合布局 - 首屏瀑布流，后续网格
  hybrid,
}

/// 设备类型枚举
enum DeviceType {
  phonePortrait,
  phoneLandscape,
  smallTablet,
  largeTablet,
  foldableFolded,
  foldableUnfolded,
}

/// 屏幕指标信息
@immutable
class ScreenMetrics {
  final Size size;
  final double pixelRatio;
  final Orientation orientation;
  final DeviceType deviceType;
  final bool isTablet;
  final EdgeInsets safeArea;

  const ScreenMetrics({
    required this.size,
    required this.pixelRatio,
    required this.orientation,
    required this.deviceType,
    required this.isTablet,
    required this.safeArea,
  });

  double get width => size.width;
  double get height => size.height;
  double get shortestSide => size.shortestSide;

  /// 计算最优列数
  int get optimalColumns {
    return calculateOptimalColumns(width);
  }

  /// 计算最大列数（用于紧凑展示）
  int get maxColumns {
    return (width / LayoutConstants.minCardWidth).floor().clamp(1, 6);
  }

  static int calculateOptimalColumns(double width) {
    if (width < LayoutConstants.phoneBreakpoint) {
      return 2;
    } else if (width < LayoutConstants.tabletBreakpoint) {
      return 3;
    } else if (width < LayoutConstants.desktopBreakpoint) {
      return 4;
    } else {
      return 5;
    }
  }

  /// 从 BuildContext 创建 ScreenMetrics
  factory ScreenMetrics.fromContext(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final shortestSide = size.shortestSide;

    DeviceType deviceType;
    if (shortestSide < LayoutConstants.phoneBreakpoint) {
      deviceType = size.width > size.height
          ? DeviceType.phoneLandscape
          : DeviceType.phonePortrait;
    } else if (shortestSide < LayoutConstants.tabletBreakpoint) {
      deviceType = DeviceType.smallTablet;
    } else {
      deviceType = DeviceType.largeTablet;
    }

    return ScreenMetrics(
      size: size,
      pixelRatio: mediaQuery.devicePixelRatio,
      orientation: mediaQuery.orientation,
      deviceType: deviceType,
      isTablet: shortestSide >= LayoutConstants.phoneBreakpoint,
      safeArea: mediaQuery.padding,
    );
  }

  ScreenMetrics copyWith({
    Size? size,
    double? pixelRatio,
    Orientation? orientation,
    DeviceType? deviceType,
    bool? isTablet,
    EdgeInsets? safeArea,
  }) {
    return ScreenMetrics(
      size: size ?? this.size,
      pixelRatio: pixelRatio ?? this.pixelRatio,
      orientation: orientation ?? this.orientation,
      deviceType: deviceType ?? this.deviceType,
      isTablet: isTablet ?? this.isTablet,
      safeArea: safeArea ?? this.safeArea,
    );
  }
}

/// 用户浏览意图枚举
enum BrowseIntent {
  /// 搜索特定内容 - 需要高信息密度
  search,

  /// 发现新内容 - 需要视觉吸引
  discover,

  /// 回顾/管理内容 - 需要紧凑高效
  review,

  /// 浏览动态 - 内容类型混杂
  browseDynamics,
}

/// 内容特征分析结果
@immutable
class ContentProfile {
  final double averageTitleLength;
  final double titleLengthVariance;
  final bool hasMixedTypes;
  final bool hasVariableAspectRatios;
  final double averageContentHeight;
  final ContentDensity density;

  const ContentProfile({
    required this.averageTitleLength,
    required this.titleLengthVariance,
    required this.hasMixedTypes,
    required this.hasVariableAspectRatios,
    required this.averageContentHeight,
    required this.density,
  });

  /// 基于内容列表创建 ContentProfile
  static ContentProfile analyze<T>(
    List<T> items,
    ContentExtractor<T> extractor,
  ) {
    if (items.isEmpty) {
      return const ContentProfile(
        averageTitleLength: 0,
        titleLengthVariance: 0,
        hasMixedTypes: false,
        hasVariableAspectRatios: false,
        averageContentHeight: 200,
        density: ContentDensity.normal,
      );
    }

    final titles = items.map((i) => extractor.extractTitle(i)).toList();
    final types = items.map((i) => extractor.extractType(i)).toSet();
    final aspectRatios = items
        .map((i) => extractor.extractAspectRatio(i))
        .toList();

    final avgTitleLength =
        titles.map((t) => t.length).reduce((a, b) => a + b) / titles.length;
    final titleVariance = _calculateVariance(
      titles.map((t) => t.length.toDouble()).toList(),
    );

    return ContentProfile(
      averageTitleLength: avgTitleLength,
      titleLengthVariance: titleVariance,
      hasMixedTypes: types.length > 1,
      hasVariableAspectRatios: _calculateVariance(aspectRatios) > 0.1,
      averageContentHeight: extractor.estimateAverageHeight(items),
      density: _calculateDensity(avgTitleLength, items.length),
    );
  }

  static double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => (v - mean) * (v - mean));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  static ContentDensity _calculateDensity(
    double avgTitleLength,
    int itemCount,
  ) {
    if (avgTitleLength > 40) return ContentDensity.high;
    if (avgTitleLength < 20) return ContentDensity.low;
    return ContentDensity.normal;
  }
}

/// 内容密度枚举
enum ContentDensity { low, normal, high }

/// 内容提取器接口
abstract class ContentExtractor<T> {
  String extractTitle(T item);
  String extractType(T item);
  double extractAspectRatio(T item);
  double estimateAverageHeight(List<T> items);
}

/// 布局配置
@immutable
class LayoutConfig {
  final LayoutType type;
  final int columns;
  final double spacing;
  final double cardAspectRatio;
  final bool useSidebar;
  final InformationDensity informationDensity;
  final ScrollPhysics? physics;

  const LayoutConfig({
    required this.type,
    required this.columns,
    required this.spacing,
    required this.cardAspectRatio,
    this.useSidebar = false,
    this.informationDensity = InformationDensity.normal,
    this.physics,
  });

  /// 创建单列列表配置
  factory LayoutConfig.list({
    double spacing = LayoutConstants.listSpacing,
    InformationDensity density = InformationDensity.high,
  }) {
    return LayoutConfig(
      type: LayoutType.list,
      columns: 1,
      spacing: spacing,
      cardAspectRatio: LayoutConstants.aspectRatio,
      informationDensity: density,
    );
  }

  /// 创建网格配置
  factory LayoutConfig.grid({
    required int columns,
    double spacing = LayoutConstants.gridSpacing,
    double aspectRatio = LayoutConstants.aspectRatio,
    bool useSidebar = false,
  }) {
    return LayoutConfig(
      type: LayoutType.grid,
      columns: columns,
      spacing: spacing,
      cardAspectRatio: aspectRatio,
      useSidebar: useSidebar,
    );
  }

  /// 创建瀑布流配置
  factory LayoutConfig.waterfall({
    required int columns,
    double spacing = LayoutConstants.gridSpacing,
    bool useSidebar = false,
  }) {
    return LayoutConfig(
      type: LayoutType.waterfall,
      columns: columns,
      spacing: spacing,
      cardAspectRatio: LayoutConstants.aspectRatio,
      useSidebar: useSidebar,
    );
  }

  /// 计算实际卡片宽度
  double calculateCardWidth(double screenWidth) {
    final totalSpacing = spacing * (columns - 1);
    return (screenWidth - totalSpacing) / columns;
  }

  /// 检查配置是否有效
  bool isValidFor(ScreenMetrics metrics) {
    final cardWidth = calculateCardWidth(metrics.width);
    return cardWidth >= LayoutConstants.minCardWidth &&
        cardWidth <= LayoutConstants.maxCardWidth;
  }

  LayoutConfig copyWith({
    LayoutType? type,
    int? columns,
    double? spacing,
    double? cardAspectRatio,
    bool? useSidebar,
    InformationDensity? informationDensity,
    ScrollPhysics? physics,
  }) {
    return LayoutConfig(
      type: type ?? this.type,
      columns: columns ?? this.columns,
      spacing: spacing ?? this.spacing,
      cardAspectRatio: cardAspectRatio ?? this.cardAspectRatio,
      useSidebar: useSidebar ?? this.useSidebar,
      informationDensity: informationDensity ?? this.informationDensity,
      physics: physics ?? this.physics,
    );
  }
}

/// 信息密度枚举
enum InformationDensity { minimal, low, normal, high, maximum }
