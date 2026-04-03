import 'package:PiliPro/http/loading_state.dart';
import 'package:PiliPro/http/video.dart';
import 'package:PiliPro/models_new/home/rcmd/result.dart';
import 'package:PiliPro/models_new/model_rec_video_item.dart';
import 'package:PiliPro/models_new/model_video.dart';
import 'package:PiliPro/pages/common/common_list_controller.dart';
import 'package:PiliPro/utils/recommend_filter.dart';
import 'package:PiliPro/utils/storage_pref.dart';

class RcmdController extends CommonListController {
  late bool enableSaveLastData = Pref.enableSaveLastData;
  final bool appRcmd = Pref.appRcmd;

  int? lastRefreshAt;
  late bool savedRcmdTip = Pref.savedRcmdTip;
  RecommendationContext recommendationContext =
      RecommendFilter.currentContext();

  @override
  void onInit() {
    super.onInit();
    page = 0;
    queryData();
  }

  @override
  Future<LoadingState> customGetData() {
    return appRcmd
        ? VideoHttp.rcmdVideoListApp(freshIdx: page)
        : VideoHttp.rcmdVideoList(freshIdx: page, ps: 20);
  }

  @override
  void handleListResponse(List dataList) {
    recommendationContext = RecommendFilter.currentContext();

    final deduplicated =
        RecommendFilter.deduplicateRecommendations<BaseVideoItemModel>(
          dataList.whereType<BaseVideoItemModel>().toList(),
        );
    if (deduplicated.length != dataList.length) {
      dataList
        ..clear()
        ..addAll(deduplicated);
    }

    // 应用智能重排序（基于质量评分）
    if (Pref.enableQualityScoring && dataList.isNotEmpty) {
      try {
        if (appRcmd) {
          final reordered =
              RecommendFilter.reorderRecommendations<RecVideoItemAppModel>(
                dataList.cast<RecVideoItemAppModel>(),
                shuffleExploration: true,
                context: recommendationContext,
              );
          dataList
            ..clear()
            ..addAll(reordered);
        } else {
          final reordered =
              RecommendFilter.reorderRecommendations<RecVideoItemModel>(
                dataList.cast<RecVideoItemModel>(),
                shuffleExploration: true,
                context: recommendationContext,
              );
          dataList
            ..clear()
            ..addAll(reordered);
        }
      } catch (e) {
        // 重排序失败时保持原样
      }
    }

    final typedDataList = dataList.whereType<BaseVideoItemModel>().toList();
    if (typedDataList.isNotEmpty) {
      Pref.rememberRecommendationBatch(typedDataList);
    }

    if (enableSaveLastData && page == 0) {
      if (loadingState.value case Success(:final response)) {
        if (response != null && response.isNotEmpty) {
          if (savedRcmdTip) {
            lastRefreshAt = dataList.length;
          }
          if (response.length > 200) {
            dataList.addAll(response.take(50));
          } else {
            dataList.addAll(response);
          }
        }
      }
    }
  }

  @override
  Future<void> onRefresh() {
    page = 0;
    isEnd = false;
    recommendationContext = RecommendFilter.currentContext();
    return queryData();
  }

  void removeRecommendationAt(int index) {
    if (loadingState.value case Success(:final response)) {
      final list = response;
      if (list == null || index < 0 || index >= list.length) {
        return;
      }
      final item = list[index];
      if (item is BaseVideoItemModel) {
        Pref.markRecommendationSkipped(item);
      }
      if (lastRefreshAt != null && index < lastRefreshAt!) {
        lastRefreshAt = lastRefreshAt! - 1;
      }
      list.removeAt(index);
      loadingState.refresh();
    }
  }
}
