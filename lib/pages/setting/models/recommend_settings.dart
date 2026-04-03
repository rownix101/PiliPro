import 'package:PiliPro/http/video.dart';
import 'package:PiliPro/pages/rcmd/controller.dart';
import 'package:PiliPro/pages/setting/models/model.dart';
import 'package:PiliPro/utils/recommend_filter.dart';
import 'package:PiliPro/utils/storage_key.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

List<SettingsModel> get recommendSettings => [
  const SwitchModel(
    title: '首页使用app端推荐',
    subtitle: '若web端推荐不太符合预期，可尝试切换至app端推荐',
    leading: Icon(Icons.model_training_outlined),
    setKey: SettingBoxKey.appRcmd,
    defaultVal: true,
    needReboot: true,
  ),
  SwitchModel(
    title: '保留首页推荐刷新',
    subtitle: '下拉刷新时保留上次内容',
    leading: const Icon(Icons.refresh),
    setKey: SettingBoxKey.enableSaveLastData,
    defaultVal: true,
    onChanged: (value) {
      try {
        Get.find<RcmdController>()
          ..enableSaveLastData = value
          ..lastRefreshAt = null;
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    },
  ),
  SwitchModel(
    title: '显示上次看到位置提示',
    subtitle: '保留上次推荐时，在上次刷新位置显示提示',
    leading: const Icon(Icons.tips_and_updates_outlined),
    setKey: SettingBoxKey.savedRcmdTip,
    defaultVal: true,
    onChanged: (value) {
      try {
        Get.find<RcmdController>()
          ..savedRcmdTip = value
          ..lastRefreshAt = null;
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    },
  ),
  getVideoFilterSelectModel(
    title: '点赞率',
    suffix: '%',
    key: SettingBoxKey.minLikeRatioForRecommend,
    values: [0, 1, 2, 3, 4],
    onChanged: (value) => RecommendFilter.minLikeRatioForRecommend = value,
  ),
  getBanWordModel(
    title: '标题关键词过滤',
    key: SettingBoxKey.banWordForRecommend,
    onChanged: (value) {
      RecommendFilter.rcmdRegExp = value;
      RecommendFilter.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  getBanWordModel(
    title: 'App推荐/热门/排行榜: 视频分区关键词过滤',
    key: SettingBoxKey.banWordForZone,
    onChanged: (value) {
      VideoHttp.zoneRegExp = value;
      VideoHttp.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  getVideoFilterSelectModel(
    title: '视频时长',
    suffix: 's',
    key: SettingBoxKey.minDurationForRcmd,
    values: [0, 30, 60, 90, 120],
    onChanged: (value) => RecommendFilter.minDurationForRcmd = value,
  ),
  getVideoFilterSelectModel(
    title: '播放量',
    key: SettingBoxKey.minPlayForRcmd,
    values: [0, 50, 100, 500, 1000],
    onChanged: (value) => RecommendFilter.minPlayForRcmd = value,
  ),
  SwitchModel(
    title: '已关注UP豁免推荐过滤',
    subtitle: '推荐中已关注用户发布的内容不会被过滤',
    leading: const Icon(Icons.favorite_border_outlined),
    setKey: SettingBoxKey.exemptFilterForFollowed,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.exemptFilterForFollowed = value,
  ),
  SwitchModel(
    title: '过滤器也应用于相关视频',
    subtitle: '视频详情页的相关视频也进行过滤¹',
    leading: const Icon(Icons.explore_outlined),
    setKey: SettingBoxKey.applyFilterToRelatedVideos,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.applyFilterToRelatedVideos = value,
  ),
  // ========== 新人UP扶持设置 ==========
  SwitchModel(
    title: '启用新人UP扶持',
    subtitle: '降低新人创作者的过滤门槛，让更多优质新内容被看到',
    leading: const Icon(Icons.person_add_outlined),
    setKey: SettingBoxKey.enableNewCreatorBoost,
    defaultVal: true,
  ),
  getVideoFilterSelectModel(
    title: '新人UP粉丝上限',
    key: SettingBoxKey.newCreatorMaxFollowers,
    values: [1000, 5000, 10000],
    defaultValue: 5000,
    isFilter: false,
  ),
  getVideoFilterSelectModel(
    title: '新人UP最低时长',
    suffix: 's',
    key: SettingBoxKey.newCreatorMinDuration,
    values: [0, 10, 15, 20, 30],
    defaultValue: 15,
    isFilter: false,
  ),
  getVideoFilterSelectModel(
    title: '新人UP最低播放量',
    key: SettingBoxKey.newCreatorMinPlay,
    values: [0, 5, 10, 20, 50],
    defaultValue: 10,
    isFilter: false,
  ),
  getVideoFilterSelectModel(
    title: '新人UP最低点赞率',
    suffix: '%',
    key: SettingBoxKey.newCreatorMinLikeRatio,
    values: [0, 1, 2, 3],
    defaultValue: 1,
    isFilter: false,
  ),
  // ========== 探索模式设置 ==========
  SwitchModel(
    title: '启用探索模式',
    subtitle: '智能穿插小众内容和新人作品，避免推荐茧房',
    leading: const Icon(Icons.explore_outlined),
    setKey: SettingBoxKey.enableExplorationMode,
    defaultVal: true,
  ),
  getVideoFilterSelectModel(
    title: '探索内容比例',
    suffix: '%',
    key: SettingBoxKey.explorationRatio,
    values: [10, 15, 20, 25, 30],
    defaultValue: 20,
    isFilter: false,
  ),
  // ========== 质量评分设置 ==========
  SwitchModel(
    title: '启用智能质量评分',
    subtitle: '基于互动深度、时效性等多维度对推荐进行重排序',
    leading: const Icon(Icons.trending_up_outlined),
    setKey: SettingBoxKey.enableQualityScoring,
    defaultVal: true,
  ),
  // ========== 负向过滤 - 低质内容拦截 ==========
  SwitchModel(
    title: '启用负向过滤',
    subtitle: '自动识别并降低标题党、擦边、低创内容的推荐权重',
    leading: const Icon(Icons.filter_alt_outlined),
    setKey: SettingBoxKey.enableNegativeFilter,
    defaultVal: true,
  ),
  getVideoFilterSelectModel(
    title: '标题党惩罚阈值',
    suffix: '%',
    key: SettingBoxKey.clickbaitPenalty,
    values: [10, 20, 30, 40, 50],
    defaultValue: 30,
    isFilter: false,
    subtitle: '检测到标题党时降低的质量分比例',
  ),
  SwitchModel(
    title: '过滤超短高播放视频',
    subtitle: '过滤时长<30秒但播放>10万的视频（疑似营销号/搬运）',
    leading: const Icon(Icons.timer_off_outlined),
    setKey: SettingBoxKey.filterShortViral,
    defaultVal: true,
  ),
  SwitchModel(
    title: '过滤可疑互动模式',
    subtitle: '过滤收藏率异常高但评论极少的视频（疑似擦边/诱导）',
    leading: const Icon(Icons.thumbs_up_down_outlined),
    setKey: SettingBoxKey.filterSuspiciousEngagement,
    defaultVal: true,
  ),
  // ========== 时长权重设置 ==========
  SwitchModel(
    title: '启用时长权重',
    subtitle: '长视频优先，短视频降权（默认3分钟内降权，8分钟以上加权）',
    leading: const Icon(Icons.timer_outlined),
    setKey: SettingBoxKey.enableDurationWeight,
    defaultVal: true,
  ),
  SwitchModel(
    title: '新人UP豁免时长限制',
    subtitle: '新人创作者不受时长权重影响',
    leading: const Icon(Icons.person_add_outlined),
    setKey: SettingBoxKey.exemptNewCreatorFromDuration,
    defaultVal: true,
  ),
  getVideoFilterSelectModel(
    title: '短视频阈值',
    suffix: 's',
    key: SettingBoxKey.shortVideoThreshold,
    values: [120, 180, 240, 300], // 2-5分钟
    defaultValue: 180,
    isFilter: false,
    subtitle: '低于此时长的视频会被降权',
  ),
  getVideoFilterSelectModel(
    title: '长视频阈值',
    suffix: 's',
    key: SettingBoxKey.longVideoThreshold,
    values: [300, 480, 600, 900], // 5-15分钟
    defaultValue: 480,
    isFilter: false,
    subtitle: '高于此时长的视频会被加权',
  ),
];
