import 'package:PiliPro/common/constants.dart';
import 'package:PiliPro/common/skeleton/video_card_v.dart';
import 'package:PiliPro/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPro/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPro/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPro/http/loading_state.dart';
import 'package:PiliPro/pages/common/common_page.dart';
import 'package:PiliPro/pages/rcmd/controller.dart';
import 'package:PiliPro/utils/grid.dart';
import 'package:PiliPro/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RcmdPage extends StatefulWidget {
  const RcmdPage({super.key});

  @override
  State<RcmdPage> createState() => _RcmdPageState();
}

class _RcmdPageState extends CommonPageState<RcmdPage, RcmdController>
    with AutomaticKeepAliveClientMixin {
  @override
  final RcmdController controller = Get.put(RcmdController());

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 提前获取主题色，避免在列表构建时重复调用
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return onBuild(
      Container(
        clipBehavior: .hardEdge,
        margin: const .symmetric(horizontal: StyleString.safeSpace),
        decoration: const BoxDecoration(borderRadius: StyleString.mdRadius),
        child: refreshIndicator(
          onRefresh: controller.onRefresh,
          child: CustomScrollView(
            controller: controller.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            // 添加缓存区域，优化滚动性能
            cacheExtent: 200,
            slivers: [
              SliverPadding(
                padding: const .only(top: StyleString.cardSpace, bottom: 100),
                sliver: Obx(
                  () => _buildBody(
                    controller.loadingState.value,
                    onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  late final gridDelegate = SliverGridDelegateWithExtentAndRatio(
    mainAxisSpacing: StyleString.cardSpace,
    crossAxisSpacing: StyleString.cardSpace,
    maxCrossAxisExtent: Pref.recommendCardWidth,
    childAspectRatio: StyleString.aspectRatio,
    mainAxisExtent: MediaQuery.textScalerOf(context).scale(90),
  );

  Widget _buildBody(
    LoadingState<List<dynamic>?> loadingState,
    Color onSurfaceVariant,
  ) {
    return switch (loadingState) {
      Loading() => _buildSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  if (index == response.length - 1) {
                    controller.onLoadMore();
                  }
                  if (controller.lastRefreshAt != null) {
                    if (controller.lastRefreshAt == index) {
                      return GestureDetector(
                        onTap: () => controller
                          ..animateToTop()
                          ..onRefresh(),
                        child: Card(
                          child: Container(
                            alignment: Alignment.center,
                            padding: const .symmetric(horizontal: 10),
                            child: Text(
                              '上次看到这里\n点击刷新',
                              textAlign: .center,
                              style: TextStyle(
                                color: onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final actualIndex = index > controller.lastRefreshAt!
                        ? index - 1
                        : index;
                    return VideoCardV(
                      videoItem: response[actualIndex],
                      onRemove: () => controller.removeRecommendationAt(
                        actualIndex,
                      ),
                    );
                  } else {
                    return VideoCardV(
                      videoItem: response[index],
                      onRemove: () => controller.removeRecommendationAt(index),
                    );
                  }
                },
                itemCount: controller.lastRefreshAt != null
                    ? response.length + 1
                    : response.length,
              )
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  Widget get _buildSkeleton => SliverGrid.builder(
    gridDelegate: gridDelegate,
    itemBuilder: (context, index) => const VideoCardVSkeleton(),
    itemCount: 10,
  );
}
