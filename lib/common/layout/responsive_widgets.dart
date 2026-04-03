import 'package:PiliPro/common/layout/layout_orchestrator.dart';
import 'package:PiliPro/common/layout/layout_types.dart';
import 'package:flutter/material.dart';

/// 响应式视频卡片
///
/// 根据布局配置自动调整信息密度和展示方式
class ResponsiveVideoCard extends StatelessWidget {
  final String title;
  final String? coverUrl;
  final String? upName;
  final String? duration;
  final String? viewCount;
  final String? danmakuCount;
  final List<String>? badges;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ResponsiveVideoCard({
    super.key,
    required this.title,
    this.coverUrl,
    this.upName,
    this.duration,
    this.viewCount,
    this.danmakuCount,
    this.badges,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final config = LayoutConfigProvider.of(context);
    final density = config?.informationDensity ?? InformationDensity.normal;

    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面区域
            _buildCover(context, density),
            // 内容区域
            _buildContent(context, density),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context, InformationDensity density) {
    return AspectRatio(
      aspectRatio: LayoutConstants.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 封面图
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: coverUrl != null
                ? Image.network(
                    coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image),
                  )
                : const Icon(Icons.image),
          ),
          // 时长标签
          if (duration != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  duration!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, InformationDensity density) {
    final theme = Theme.of(context);

    // 根据密度调整展示内容
    final showStats = density.index >= InformationDensity.normal.index;
    final showUpName = density.index >= InformationDensity.low.index;
    final maxTitleLines = switch (density) {
      InformationDensity.minimal || InformationDensity.low => 1,
      _ => 2,
    };

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Text(
            title,
            maxLines: maxTitleLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: switch (density) {
                InformationDensity.minimal => 12,
                InformationDensity.low => 13,
                _ => 14,
              },
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          // 徽章
          if (badges != null && badges!.isNotEmpty)
            Wrap(
              spacing: 4,
              children: badges!
                  .take(density == InformationDensity.high ? 3 : 1)
                  .map((badge) => _Badge(text: badge))
                  .toList(),
            ),
          // 统计信息
          if (showStats && (viewCount != null || danmakuCount != null))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  if (viewCount != null)
                    _StatItem(icon: Icons.play_arrow, value: viewCount!),
                  if (danmakuCount != null) ...[
                    const SizedBox(width: 8),
                    _StatItem(icon: Icons.chat_bubble, value: danmakuCount!),
                  ],
                ],
              ),
            ),
          // UP主名
          if (showUpName && upName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                upName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 徽章组件
class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// 统计项组件
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatItem({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 响应式列表项（水平布局）
class ResponsiveListItem extends StatelessWidget {
  final String title;
  final String? coverUrl;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ResponsiveListItem({
    super.key,
    required this.title,
    this.coverUrl,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final config = LayoutConfigProvider.of(context);
    final showSubtitle =
        config?.informationDensity.index != null &&
        config!.informationDensity.index >= InformationDensity.normal.index;

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 封面
              if (coverUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    coverUrl!,
                    width: 120,
                    height: 75,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 120,
                      height: 75,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.image),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    if (showSubtitle && subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 尾部
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 骨架屏组件
class ResponsiveSkeleton extends StatelessWidget {
  final LayoutType? layoutType;
  final int itemCount;

  const ResponsiveSkeleton({
    super.key,
    this.layoutType,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    final config = LayoutConfigProvider.of(context);
    final type = layoutType ?? config?.type ?? LayoutType.grid;
    final columns = config?.columns ?? 2;

    return switch (type) {
      LayoutType.list => _buildListSkeleton(),
      _ => _buildGridSkeleton(columns),
    };
  }

  Widget _buildListSkeleton() {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _SkeletonCard(isHorizontal: true),
      ),
    );
  }

  Widget _buildGridSkeleton(int columns) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: LayoutConstants.aspectRatio * 1.5,
      ),
      itemCount: itemCount,
      itemBuilder: (_, __) => const _SkeletonCard(isHorizontal: false),
    );
  }
}

/// 骨架卡片
class _SkeletonCard extends StatelessWidget {
  final bool isHorizontal;

  const _SkeletonCard({required this.isHorizontal});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    if (isHorizontal) {
      return Row(
        children: [
          Container(
            width: 120,
            height: 75,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: LayoutConstants.aspectRatio,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 12,
          width: 80,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
