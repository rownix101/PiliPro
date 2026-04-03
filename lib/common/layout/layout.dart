/// 响应式布局架构
///
/// PiliPro 的新一代布局系统，提供统一的、智能的、自适应的布局解决方案。
///
/// ## 快速开始
///
/// ```dart
/// import 'package:PiliPro/common/layout/layout.dart';
///
/// // 基础使用
/// ResponsiveLayoutBuilder(
///   intent: BrowseIntent.discover,
///   itemCount: videos.length,
///   itemBuilder: (context, index) => VideoCard(video: videos[index]),
/// )
/// ```
///
/// ## 更多文档
///
/// - [快速参考](./QUICK_REFERENCE.md)
/// - [架构文档](./ARCHITECTURE.md)
/// - [迁移指南](./MIGRATION_GUIDE.md)
/// - [代码示例](./examples.dart)
library;

// 核心类型
export 'layout_types.dart';

// 策略引擎
export 'layout_strategy.dart';

// 布局协调器
export 'layout_orchestrator.dart';

// 响应式组件
export 'responsive_widgets.dart';
