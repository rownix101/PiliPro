import 'dart:io';
import 'dart:math' show pow, sqrt;

import 'package:PiliPro/common/widgets/pair.dart';
import 'package:PiliPro/http/constants.dart';
import 'package:PiliPro/models_new/common/dynamic/dynamic_badge_mode.dart';
import 'package:PiliPro/models_new/common/dynamic/dynamics_type.dart';
import 'package:PiliPro/models_new/common/dynamic/up_panel_position.dart';
import 'package:PiliPro/models_new/common/follow_order_type.dart';
import 'package:PiliPro/models_new/common/member/tab_type.dart';
import 'package:PiliPro/models_new/common/msg/msg_unread_type.dart';
import 'package:PiliPro/models_new/common/nav_bar_config.dart';
import 'package:PiliPro/models_new/common/reply/reply_sort_type.dart';
import 'package:PiliPro/models_new/common/sponsor_block/segment_type.dart';
import 'package:PiliPro/models_new/common/sponsor_block/skip_type.dart';
import 'package:PiliPro/models_new/common/super_chat_type.dart';
import 'package:PiliPro/models_new/common/theme/theme_type.dart';
import 'package:PiliPro/models_new/common/video/audio_quality.dart';
import 'package:PiliPro/models_new/common/video/cdn_type.dart';
import 'package:PiliPro/models_new/common/video/live_quality.dart';
import 'package:PiliPro/models_new/common/video/subtitle_pref_type.dart';
import 'package:PiliPro/models_new/common/video/video_decode_type.dart';
import 'package:PiliPro/models_new/common/video/video_quality.dart';
import 'package:PiliPro/models_new/model_video.dart';
import 'package:PiliPro/models_new/user/danmaku_rule.dart';
import 'package:PiliPro/models_new/user/info.dart';
import 'package:PiliPro/plugin/pl_player/models/bottom_progress_behavior.dart';
import 'package:PiliPro/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliPro/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPro/utils/extension/context_ext.dart';
import 'package:PiliPro/utils/extension/iterable_ext.dart';
import 'package:PiliPro/utils/global_data.dart';
import 'package:PiliPro/utils/login_utils.dart';
import 'package:PiliPro/utils/platform_utils.dart';
import 'package:PiliPro/utils/storage.dart';
import 'package:PiliPro/utils/storage_key.dart';
import 'package:PiliPro/utils/utils.dart';
import 'package:crypto/crypto.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart' show FlexSchemeVariant;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

abstract final class Pref {
  static final Box _setting = GStorage.setting;
  static final Box _video = GStorage.video;
  static final Box _localCache = GStorage.localCache;
  static final RegExp _recommendTitleNoise = RegExp(
    r'[^\u4e00-\u9fa5a-z0-9]+',
    caseSensitive: false,
  );

  static UserInfoData? get userInfoCache =>
      GStorage.userInfo.get('userInfoCache');

  static List<double> get dynamicDetailRatio => List<double>.from(
    _setting.get(
      SettingBoxKey.dynamicDetailRatio,
      defaultValue: const [60.0, 40.0],
    ),
  );

  static Set<int> get blackMids =>
      _localCache.get(LocalCacheKey.blackMids, defaultValue: <int>{});

  static set blackMids(Set<int> blackMidsSet) =>
      _localCache.put(LocalCacheKey.blackMids, blackMidsSet);

  static RuleFilter get danmakuFilterRule => _localCache.get(
    LocalCacheKey.danmakuFilterRules,
    defaultValue: RuleFilter.empty(),
  );

  static void setBlackMid(int mid) => _localCache.put(
    LocalCacheKey.blackMids,
    GlobalData().blackMids..add(mid),
  );

  static void removeBlackMid(int mid) => _localCache.put(
    LocalCacheKey.blackMids,
    GlobalData().blackMids..remove(mid),
  );

  static MemberTabType get memberTab =>
      MemberTabType.values[_setting.get(
        SettingBoxKey.memberTab,
        defaultValue: 0,
      )];

  static int get _themeTypeInt => _setting.get(
    SettingBoxKey.themeMode,
    defaultValue: ThemeType.system.index,
  );

  static ThemeType get themeType => ThemeType.values[_themeTypeInt];

  static ThemeMode get themeMode => switch (_themeTypeInt) {
    0 => ThemeMode.light,
    1 => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static List<double> get springDescription => List<double>.from(
    _setting.get(SettingBoxKey.springDescription) ??
        [0.5, 100.0, 2.2 * sqrt(50)], // [mass, stiffness, damping]
  );

  static List<double> get speedList => List<double>.from(
    _video.get(
      VideoBoxKey.speedsList,
      defaultValue: const [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0],
    ),
  );

  static List<Pair<SegmentType, SkipType>> get blockSettings {
    final list = _setting.get(SettingBoxKey.blockSettings) as List?;
    if (list == null || list.length != SegmentType.values.length) {
      return SegmentType.values
          .map((i) => Pair(first: i, second: SkipType.skipOnce))
          .toList();
    }
    return SegmentType.values
        .map(
          (item) => Pair(
            first: item,
            second: SkipType.values[list[item.index]],
          ),
        )
        .toList();
  }

  static List<Color> get blockColor {
    final list = _setting.get(SettingBoxKey.blockColor) as List?;
    if (list == null || list.length != SegmentType.values.length) {
      return SegmentType.values.map((i) => i.color).toList();
    }
    return SegmentType.values.map(
      (item) {
        final String e = list[item.index];
        final color = e.isNotEmpty ? int.tryParse('FF$e', radix: 16) : null;
        return color != null ? Color(color) : item.color;
      },
    ).toList();
  }

  static bool get feedBackEnable =>
      _setting.get(SettingBoxKey.feedBackEnable, defaultValue: false);

  static int get picQuality =>
      _setting.get(SettingBoxKey.defaultPicQa, defaultValue: 10);

  static DynamicBadgeMode get dynamicBadgeType =>
      DynamicBadgeMode.values[_setting.get(
        SettingBoxKey.dynamicBadgeMode,
        defaultValue: DynamicBadgeMode.number.index,
      )];

  static DynamicBadgeMode get msgBadgeMode =>
      DynamicBadgeMode.values[_setting.get(
        SettingBoxKey.msgBadgeMode,
        defaultValue: DynamicBadgeMode.number.index,
      )];

  static Set<MsgUnReadType> get msgUnReadTypeV2 =>
      (_setting.get(SettingBoxKey.msgUnReadTypeV2) as List?)
          ?.map((index) => MsgUnReadType.values[index])
          .toSet() ??
      MsgUnReadType.values.toSet();

  static NavigationBarType get defaultHomePage =>
      NavigationBarType.values[defaultHomePageIndex];

  static int get defaultHomePageIndex => _setting.get(
    SettingBoxKey.defaultHomePage,
    defaultValue: NavigationBarType.home.index,
  );

  static int get previewQ =>
      _setting.get(SettingBoxKey.previewQuality, defaultValue: 100);

  static double get smallCardWidth =>
      _setting.get(SettingBoxKey.smallCardWidth, defaultValue: 240.0);

  static double get recommendCardWidth =>
      _setting.get(SettingBoxKey.recommendCardWidth, defaultValue: 240.0);

  static UpPanelPosition get upPanelPosition =>
      UpPanelPosition.values[_setting.get(
        SettingBoxKey.upPanelPosition,
        defaultValue: UpPanelPosition.leftFixed.index,
      )];

  static FullScreenMode get fullScreenMode =>
      FullScreenMode.values[_setting.get(
        SettingBoxKey.fullScreenMode,
        defaultValue: FullScreenMode.auto.index,
      )];

  static BtmProgressBehavior get btmProgressBehavior =>
      BtmProgressBehavior.values[_setting.get(
        SettingBoxKey.btmProgressBehavior,
        defaultValue: BtmProgressBehavior.alwaysShow.index,
      )];

  static SubtitlePrefType get subtitlePreferenceV2 =>
      SubtitlePrefType.values[_setting.get(
        SettingBoxKey.subtitlePreferenceV2,
        defaultValue: SubtitlePrefType.off.index,
      )];

  static bool get useRelativeSlide =>
      _setting.get(SettingBoxKey.useRelativeSlide, defaultValue: false);

  static int get sliderDuration =>
      _setting.get(SettingBoxKey.sliderDuration, defaultValue: 90);

  static int get defaultVideoQa => _setting.get(
    SettingBoxKey.defaultVideoQa,
    defaultValue: VideoQuality.super8k.code,
  );

  static int get defaultVideoQaCellular => _setting.get(
    SettingBoxKey.defaultVideoQaCellular,
    defaultValue: VideoQuality.high1080.code,
  );

  static int get defaultAudioQa => _setting.get(
    SettingBoxKey.defaultAudioQa,
    defaultValue: AudioQuality.hiRes.code,
  );

  static int get defaultAudioQaCellular => _setting.get(
    SettingBoxKey.defaultAudioQaCellular,
    defaultValue: AudioQuality.k192.code,
  );

  static String get defaultDecode => _setting.get(
    SettingBoxKey.defaultDecode,
    defaultValue: VideoDecodeFormatType.AVC.codes.first,
  );

  static String get secondDecode => _setting.get(
    SettingBoxKey.secondDecode,
    defaultValue: VideoDecodeFormatType.AV1.codes.first,
  );

  static CDNService get defaultCDNService {
    if (_setting.get(SettingBoxKey.CDNService) case final String cdnName) {
      return CDNService.values.byName(cdnName);
    }
    return CDNService.backupUrl;
  }

  static String get banWordForRecommend =>
      _setting.get(SettingBoxKey.banWordForRecommend, defaultValue: '');

  static String get banWordForReply =>
      _setting.get(SettingBoxKey.banWordForReply, defaultValue: '');

  static String get banWordForZone =>
      _setting.get(SettingBoxKey.banWordForZone, defaultValue: '');

  static bool get appRcmd =>
      _setting.get(SettingBoxKey.appRcmd, defaultValue: true);

  static String get systemProxyHost =>
      _setting.get(SettingBoxKey.systemProxyHost, defaultValue: '');

  static String get systemProxyPort =>
      _setting.get(SettingBoxKey.systemProxyPort, defaultValue: '');

  static DynamicsTabType get defaultDynamicType =>
      DynamicsTabType.values[defaultDynamicTypeIndex];

  static int get defaultDynamicTypeIndex => _setting.get(
    SettingBoxKey.defaultDynamicType,
    defaultValue: DynamicsTabType.all.index,
  );

  static bool get showDynInteraction =>
      _setting.get(SettingBoxKey.showDynInteraction, defaultValue: true);

  static double get blockLimit =>
      _setting.get(SettingBoxKey.blockLimit, defaultValue: 0.0);

  static double get refreshDragPercentage =>
      _setting.get(SettingBoxKey.refreshDragPercentage, defaultValue: 0.25);

  static double get refreshDisplacement => _setting.get(
    SettingBoxKey.refreshDisplacement,
    defaultValue: PlatformUtils.isMobile ? 20.0 : 40.0,
  );

  static String get blockUserID {
    String? blockUserID = _setting.get(SettingBoxKey.blockUserID);
    if (blockUserID == null || blockUserID.isEmpty) {
      blockUserID = Digest(
        List.generate(16, (_) => Utils.random.nextInt(256)),
      ).toString();
      _setting.put(SettingBoxKey.blockUserID, blockUserID);
    }
    return blockUserID;
  }

  static bool get blockToast =>
      _setting.get(SettingBoxKey.blockToast, defaultValue: true);

  static String get blockServer => _setting.get(
    SettingBoxKey.blockServer,
    defaultValue: HttpString.sponsorBlockBaseUrl,
  );

  static bool get blockTrack =>
      _setting.get(SettingBoxKey.blockTrack, defaultValue: !kDebugMode);

  static bool get checkDynamic =>
      _setting.get(SettingBoxKey.checkDynamic, defaultValue: true);

  static int get dynamicPeriod =>
      _setting.get(SettingBoxKey.dynamicPeriod, defaultValue: 5);

  static FlexSchemeVariant get schemeVariant =>
      FlexSchemeVariant.values[_setting.get(
        SettingBoxKey.schemeVariant,
        defaultValue: FlexSchemeVariant.material3Legacy.index,
      )];

  static double get danmakuFontScaleFS => _setting.get(
    SettingBoxKey.danmakuFontScaleFS,
    defaultValue: PlatformUtils.isMobile ? 1.2 : 1.7,
  );

  static bool get danmakuMassiveMode =>
      _setting.get(SettingBoxKey.danmakuMassiveMode, defaultValue: false);

  static bool get danmakuFixedV =>
      _setting.get(SettingBoxKey.danmakuFixedV, defaultValue: false);

  static bool get danmakuStatic2Scroll =>
      _setting.get(SettingBoxKey.danmakuStatic2Scroll, defaultValue: false);

  static double get subtitleFontScale =>
      _setting.get(SettingBoxKey.subtitleFontScale, defaultValue: 1.0);

  static double get subtitleFontScaleFS =>
      _setting.get(SettingBoxKey.subtitleFontScaleFS, defaultValue: 1.5);

  static bool get showViewPoints =>
      _setting.get(SettingBoxKey.showViewPoints, defaultValue: true);

  static bool get showRelatedVideo =>
      _setting.get(SettingBoxKey.showRelatedVideo, defaultValue: true);

  static bool get showVideoReply =>
      _setting.get(SettingBoxKey.showVideoReply, defaultValue: true);

  static bool get showBangumiReply =>
      _setting.get(SettingBoxKey.showBangumiReply, defaultValue: true);

  static bool get alwaysExpandIntroPanel =>
      _setting.get(SettingBoxKey.alwaysExpandIntroPanel, defaultValue: false);

  static bool get expandIntroPanelH =>
      _setting.get(SettingBoxKey.expandIntroPanelH, defaultValue: false);

  static bool get horizontalSeasonPanel => _setting.get(
    SettingBoxKey.horizontalSeasonPanel,
    defaultValue: PlatformUtils.isDesktop,
  );

  static bool get horizontalMemberPage => _setting.get(
    SettingBoxKey.horizontalMemberPage,
    defaultValue: PlatformUtils.isDesktop,
  );

  static int? get replyLengthLimit {
    int length = _setting.get(SettingBoxKey.replyLengthLimit, defaultValue: 6);
    if (length <= 0) {
      return null;
    }
    return length;
  }

  static int get defaultPicQa =>
      _setting.get(SettingBoxKey.defaultPicQa, defaultValue: 10);

  static double get danmakuLineHeight =>
      _setting.get(SettingBoxKey.danmakuLineHeight, defaultValue: 1.6);

  static bool get showArgueMsg =>
      _setting.get(SettingBoxKey.showArgueMsg, defaultValue: true);

  static bool get reverseFromFirst =>
      _setting.get(SettingBoxKey.reverseFromFirst, defaultValue: true);

  static int get subtitlePaddingH =>
      _setting.get(SettingBoxKey.subtitlePaddingH, defaultValue: 24);

  static int get subtitlePaddingB =>
      _setting.get(SettingBoxKey.subtitlePaddingB, defaultValue: 24);

  static double get subtitleBgOpacity =>
      _setting.get(SettingBoxKey.subtitleBgOpacity, defaultValue: 0.67);

  static double get subtitleStrokeWidth =>
      _setting.get(SettingBoxKey.subtitleStrokeWidth, defaultValue: 2.0);

  static int get subtitleFontWeight =>
      _setting.get(SettingBoxKey.subtitleFontWeight, defaultValue: 5);

  static bool get badCertificateCallback =>
      _setting.get(SettingBoxKey.badCertificateCallback, defaultValue: false);

  static bool get continuePlayingPart =>
      _setting.get(SettingBoxKey.continuePlayingPart, defaultValue: true);

  static bool get cdnSpeedTest =>
      _setting.get(SettingBoxKey.cdnSpeedTest, defaultValue: true);

  static bool get autoUpdate =>
      _setting.get(SettingBoxKey.autoUpdate, defaultValue: true);

  static bool get horizontalPreview =>
      _setting.get(SettingBoxKey.horizontalPreview, defaultValue: false);

  static bool get openInBrowser =>
      _setting.get(SettingBoxKey.openInBrowser, defaultValue: false);

  static bool get savedRcmdTip =>
      _setting.get(SettingBoxKey.savedRcmdTip, defaultValue: true);

  static bool get showVipDanmaku =>
      _setting.get(SettingBoxKey.showVipDanmaku, defaultValue: true);

  static bool get mergeDanmaku =>
      _setting.get(SettingBoxKey.mergeDanmaku, defaultValue: false);

  static bool get showHotRcmd =>
      _setting.get(SettingBoxKey.showHotRcmd, defaultValue: false);

  static String get audioNormalization =>
      _setting.get(SettingBoxKey.audioNormalization, defaultValue: '0');

  static String get fallbackNormalization =>
      _setting.get(SettingBoxKey.fallbackNormalization, defaultValue: '0');

  static bool get preInitPlayer =>
      _setting.get(SettingBoxKey.preInitPlayer, defaultValue: false);

  static bool get mainTabBarView =>
      _setting.get(SettingBoxKey.mainTabBarView, defaultValue: false);

  static bool get searchSuggestion =>
      _setting.get(SettingBoxKey.searchSuggestion, defaultValue: true);

  static bool get showDynDecorate =>
      _setting.get(SettingBoxKey.showDynDecorate, defaultValue: true);

  static bool get enableLivePhoto =>
      _setting.get(SettingBoxKey.enableLivePhoto, defaultValue: true);

  static bool get showSeekPreview =>
      _setting.get(SettingBoxKey.showSeekPreview, defaultValue: true);

  static bool get showDmChart =>
      _setting.get(SettingBoxKey.showDmChart, defaultValue: false);

  static bool get enableCommAntifraud =>
      _setting.get(SettingBoxKey.enableCommAntifraud, defaultValue: false);

  static bool get biliSendCommAntifraud =>
      Platform.isAndroid &&
      _setting.get(SettingBoxKey.biliSendCommAntifraud, defaultValue: false);

  static bool get enableCreateDynAntifraud =>
      _setting.get(SettingBoxKey.enableCreateDynAntifraud, defaultValue: false);

  static bool get coinWithLike =>
      _setting.get(SettingBoxKey.coinWithLike, defaultValue: false);

  static bool get isPureBlackTheme =>
      _setting.get(SettingBoxKey.isPureBlackTheme, defaultValue: false);

  static bool get antiGoodsDyn =>
      _setting.get(SettingBoxKey.antiGoodsDyn, defaultValue: false);

  static bool get antiGoodsReply =>
      _setting.get(SettingBoxKey.antiGoodsReply, defaultValue: false);

  static bool get expandDynLivePanel =>
      _setting.get(SettingBoxKey.expandDynLivePanel, defaultValue: false);

  static bool get slideDismissReplyPage => _setting.get(
    SettingBoxKey.slideDismissReplyPage,
    defaultValue: Platform.isIOS,
  );

  static bool get showFSActionItem =>
      _setting.get(SettingBoxKey.showFSActionItem, defaultValue: true);

  static bool get enableShrinkVideoSize =>
      _setting.get(SettingBoxKey.enableShrinkVideoSize, defaultValue: true);

  static bool get showDynActionBar =>
      _setting.get(SettingBoxKey.showDynActionBar, defaultValue: true);

  static bool get darkVideoPage =>
      _setting.get(SettingBoxKey.darkVideoPage, defaultValue: false);

  static bool get enableSlideVolumeBrightness => _setting.get(
    SettingBoxKey.enableSlideVolumeBrightness,
    defaultValue: true,
  );

  static bool get enableSlideFS =>
      _setting.get(SettingBoxKey.enableSlideFS, defaultValue: true);

  static int get retryCount =>
      _setting.get(SettingBoxKey.retryCount, defaultValue: 2);

  static int get retryDelay =>
      _setting.get(SettingBoxKey.retryDelay, defaultValue: 500);

  static int get liveQuality => _setting.get(
    SettingBoxKey.liveQuality,
    defaultValue: LiveQuality.origin.code,
  );

  static int get liveQualityCellular => _setting.get(
    SettingBoxKey.liveQualityCellular,
    defaultValue: LiveQuality.superHD.code,
  );

  static int get appFontWeight =>
      _setting.get(SettingBoxKey.appFontWeight, defaultValue: -1);

  static bool get enableDragSubtitle =>
      _setting.get(SettingBoxKey.enableDragSubtitle, defaultValue: false);

  static int get fastForBackwardDuration =>
      _setting.get(SettingBoxKey.fastForBackwardDuration, defaultValue: 10);

  static bool get recordSearchHistory =>
      _setting.get(SettingBoxKey.recordSearchHistory, defaultValue: true);

  static String get webdavUri =>
      _setting.get(SettingBoxKey.webdavUri, defaultValue: '');

  static String get webdavUsername =>
      _setting.get(SettingBoxKey.webdavUsername, defaultValue: '');

  static String get webdavPassword =>
      _setting.get(SettingBoxKey.webdavPassword, defaultValue: '');

  static String get webdavDirectory =>
      _setting.get(SettingBoxKey.webdavDirectory, defaultValue: '/');

  static bool get showPgcTimeline =>
      _setting.get(SettingBoxKey.showPgcTimeline, defaultValue: true);

  static num get maxCacheSize =>
      _setting.get(SettingBoxKey.maxCacheSize) ?? pow(1024, 3);

  static bool get optTabletNav =>
      _setting.get(SettingBoxKey.optTabletNav, defaultValue: true);

  static bool get horizontalScreen =>
      _setting.get(SettingBoxKey.horizontalScreen) ?? isTablet;

  static bool get isTablet {
    bool isTablet;
    if (Get.context != null) {
      isTablet = Get.context!.isTablet;
    } else {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final screenSize = view.physicalSize / view.devicePixelRatio;
      isTablet = screenSize.shortestSide >= 600;
    }
    _setting.put(SettingBoxKey.horizontalScreen, isTablet);
    return isTablet;
  }

  static String get banWordForDyn =>
      _setting.get(SettingBoxKey.banWordForDyn, defaultValue: '');

  static bool get enableLog =>
      _setting.get(SettingBoxKey.enableLog, defaultValue: true);

  static bool get disableAudioCDN =>
      _setting.get(SettingBoxKey.disableAudioCDN, defaultValue: false);

  static int get minDurationForRcmd =>
      _setting.get(SettingBoxKey.minDurationForRcmd, defaultValue: 0);

  static int get minPlayForRcmd =>
      _setting.get(SettingBoxKey.minPlayForRcmd, defaultValue: 0);

  static int get minLikeRatioForRecommend =>
      _setting.get(SettingBoxKey.minLikeRatioForRecommend, defaultValue: 0);

  static List<String> get recentRecommendationVideoKeys => List<String>.from(
    _localCache.get(
      LocalCacheKey.recentRecommendationVideoKeys,
      defaultValue: const <String>[],
    ),
  );

  static List<int> get recentRecommendationOwnerIds => List<int>.from(
    _localCache.get(
      LocalCacheKey.recentRecommendationOwnerIds,
      defaultValue: const <int>[],
    ),
  );

  static List<String> get recentRecommendationTitleFingerprints =>
      List<String>.from(
        _localCache.get(
          LocalCacheKey.recentRecommendationTitleFingerprints,
          defaultValue: const <String>[],
        ),
      );

  static List<String> get skippedRecommendationVideoKeys => List<String>.from(
    _localCache.get(
      LocalCacheKey.skippedRecommendationVideoKeys,
      defaultValue: const <String>[],
    ),
  );

  static List<int> get skippedRecommendationOwnerIds => List<int>.from(
    _localCache.get(
      LocalCacheKey.skippedRecommendationOwnerIds,
      defaultValue: const <int>[],
    ),
  );

  static List<String> get skippedRecommendationTitleFingerprints =>
      List<String>.from(
        _localCache.get(
          LocalCacheKey.skippedRecommendationTitleFingerprints,
          defaultValue: const <String>[],
        ),
      );

  static String recommendationVideoKey(BaseVideoItemModel item) {
    if (item.bvid?.isNotEmpty == true) {
      return 'bvid:${item.bvid}';
    }
    if (item.aid != null) {
      return 'aid:${item.aid}';
    }
    if (item.cid != null) {
      return 'cid:${item.cid}';
    }
    return '';
  }

  static String recommendationTitleFingerprint(String title) {
    final normalized = title
        .toLowerCase()
        .replaceAll(_recommendTitleNoise, ' ')
        .trim();
    if (normalized.isEmpty) {
      return '';
    }
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 2)
        .take(4)
        .toList();
    if (tokens.isEmpty) {
      return normalized.length > 12 ? normalized.substring(0, 12) : normalized;
    }
    return tokens.join(' ');
  }

  static Future<void> rememberRecommendationBatch(
    Iterable<BaseVideoItemModel> items, {
    int limit = 40,
  }) async {
    final videoKeys = <String>[];
    final ownerIds = <int>[];
    final titleFingerprints = <String>[];

    for (final item in items.take(limit)) {
      final key = recommendationVideoKey(item);
      if (key.isNotEmpty) {
        videoKeys.add(key);
      }
      final ownerId = item.owner.mid;
      if (ownerId != null && ownerId > 0) {
        ownerIds.add(ownerId);
      }
      final fingerprint = recommendationTitleFingerprint(item.title);
      if (fingerprint.isNotEmpty) {
        titleFingerprints.add(fingerprint);
      }
    }

    await _localCache.put(
      LocalCacheKey.recentRecommendationVideoKeys,
      _mergeRecent(videoKeys, recentRecommendationVideoKeys, 160),
    );
    await _localCache.put(
      LocalCacheKey.recentRecommendationOwnerIds,
      _mergeRecent(ownerIds, recentRecommendationOwnerIds, 120),
    );
    await _localCache.put(
      LocalCacheKey.recentRecommendationTitleFingerprints,
      _mergeRecent(
        titleFingerprints,
        recentRecommendationTitleFingerprints,
        120,
      ),
    );
  }

  static Future<void> markRecommendationSkipped(BaseVideoItemModel item) async {
    final key = recommendationVideoKey(item);
    final ownerId = item.owner.mid;
    final fingerprint = recommendationTitleFingerprint(item.title);

    if (key.isNotEmpty) {
      await _localCache.put(
        LocalCacheKey.skippedRecommendationVideoKeys,
        _mergeRecent([key], skippedRecommendationVideoKeys, 80),
      );
    }
    if (ownerId != null && ownerId > 0) {
      await _localCache.put(
        LocalCacheKey.skippedRecommendationOwnerIds,
        _mergeRecent([ownerId], skippedRecommendationOwnerIds, 80),
      );
    }
    if (fingerprint.isNotEmpty) {
      await _localCache.put(
        LocalCacheKey.skippedRecommendationTitleFingerprints,
        _mergeRecent([fingerprint], skippedRecommendationTitleFingerprints, 80),
      );
    }
  }

  static bool get exemptFilterForFollowed =>
      _setting.get(SettingBoxKey.exemptFilterForFollowed, defaultValue: true);

  static bool get applyFilterToRelatedVideos => _setting.get(
    SettingBoxKey.applyFilterToRelatedVideos,
    defaultValue: true,
  );

  // ========== 新人UP扶持设置 ==========
  static bool get enableNewCreatorBoost => _setting.get(
    SettingBoxKey.enableNewCreatorBoost,
    defaultValue: true, // 默认开启新人扶持
  );

  static int get newCreatorMaxFollowers => _setting.get(
    SettingBoxKey.newCreatorMaxFollowers,
    defaultValue: 5000, // 粉丝少于5000视为新人UP
  );

  static int get newCreatorMinDuration => _setting.get(
    SettingBoxKey.newCreatorMinDuration,
    defaultValue: 15, // 新人UP视频最低15秒（普通是30秒）
  );

  static int get newCreatorMinPlay => _setting.get(
    SettingBoxKey.newCreatorMinPlay,
    defaultValue: 10, // 新人UP最低10播放量（普通是50/100）
  );

  static int get newCreatorMinLikeRatio => _setting.get(
    SettingBoxKey.newCreatorMinLikeRatio,
    defaultValue: 1, // 新人UP最低1%点赞率（普通是2-4%）
  );

  // ========== 探索模式设置 ==========
  static bool get enableExplorationMode => _setting.get(
    SettingBoxKey.enableExplorationMode,
    defaultValue: true,
  );

  static double get explorationRatio => _setting.get(
    SettingBoxKey.explorationRatio,
    defaultValue: 0.20, // 默认20%内容用于探索小众/新人
  );

  // ========== 多样性配额设置 ==========
  static bool get enableDiversityQuota => _setting.get(
    SettingBoxKey.enableDiversityQuota,
    defaultValue: true,
  );

  static double get nicheContentRatio => _setting.get(
    SettingBoxKey.nicheContentRatio,
    defaultValue: 0.15, // 15%小众内容配额
  );

  // ========== 质量评分设置 ==========
  static bool get enableQualityScoring => _setting.get(
    SettingBoxKey.enableQualityScoring,
    defaultValue: true,
  );

  static double get engagementWeight => _setting.get(
    SettingBoxKey.engagementWeight,
    defaultValue: 0.4, // 互动率权重40%
  );

  static double get depthWeight => _setting.get(
    SettingBoxKey.depthWeight,
    defaultValue: 0.3, // 深度指标权重30%
  );

  static double get freshnessWeight => _setting.get(
    SettingBoxKey.freshnessWeight,
    defaultValue: 0.3, // 时效性权重30%
  );

  // ========== 负向过滤设置 ==========
  static bool get enableNegativeFilter => _setting.get(
    SettingBoxKey.enableNegativeFilter,
    defaultValue: true,
  );

  static int get clickbaitPenalty => _setting.get(
    SettingBoxKey.clickbaitPenalty,
    defaultValue: 30, // 默认30%惩罚
  );

  static bool get filterShortViral => _setting.get(
    SettingBoxKey.filterShortViral,
    defaultValue: true,
  );

  static bool get filterSuspiciousEngagement => _setting.get(
    SettingBoxKey.filterSuspiciousEngagement,
    defaultValue: true,
  );

  // ========== 时长权重设置 ==========
  static bool get enableDurationWeight => _setting.get(
    SettingBoxKey.enableDurationWeight,
    defaultValue: true,
  );

  static int get shortVideoThreshold => _setting.get(
    SettingBoxKey.shortVideoThreshold,
    defaultValue: 180, // 3分钟
  );

  static int get longVideoThreshold => _setting.get(
    SettingBoxKey.longVideoThreshold,
    defaultValue: 480, // 8分钟
  );

  static bool get exemptNewCreatorFromDuration => _setting.get(
    SettingBoxKey.exemptNewCreatorFromDuration,
    defaultValue: true, // 新人UP豁免时长限制
  );

  static bool get enableBackgroundPlay =>
      _setting.get(SettingBoxKey.enableBackgroundPlay, defaultValue: true);

  static bool get allowRotateScreen =>
      _setting.get(SettingBoxKey.allowRotateScreen, defaultValue: true);

  static bool get disableLikeMsg =>
      _setting.get(SettingBoxKey.disableLikeMsg, defaultValue: false);

  static bool get enableWordRe =>
      _setting.get(SettingBoxKey.enableWordRe, defaultValue: false);

  static bool get autoExitFullscreen =>
      _setting.get(SettingBoxKey.enableAutoExit, defaultValue: true);

  static bool get autoPlayEnable =>
      _setting.get(SettingBoxKey.autoPlayEnable, defaultValue: false);

  static bool get pipNoDanmaku =>
      _setting.get(SettingBoxKey.pipNoDanmaku, defaultValue: false);

  static bool get enableVerticalExpand =>
      _setting.get(SettingBoxKey.enableVerticalExpand, defaultValue: false);

  static double get defaultTextScale =>
      _setting.get(SettingBoxKey.defaultTextScale, defaultValue: 1.0);

  static double get uiScale =>
      _setting.get(SettingBoxKey.uiScale, defaultValue: 1.0);

  static bool get dynamicsWaterfallFlow =>
      _setting.get(SettingBoxKey.dynamicsWaterfallFlow, defaultValue: true);

  static bool get hideTopBar => _setting.get(
    SettingBoxKey.hideTopBar,
    defaultValue: PlatformUtils.isMobile,
  );

  static bool get hideBottomBar => _setting.get(
    SettingBoxKey.hideBottomBar,
    defaultValue: PlatformUtils.isMobile,
  );

  static bool get enableScrollThreshold =>
      _setting.get(SettingBoxKey.enableScrollThreshold, defaultValue: false);

  static double get scrollThreshold =>
      _setting.get(SettingBoxKey.scrollThreshold, defaultValue: 50.0);

  static bool get enableSearchWord =>
      _setting.get(SettingBoxKey.enableSearchWord, defaultValue: false);

  static bool get useSideBar =>
      _setting.get(SettingBoxKey.useSideBar, defaultValue: false);

  static bool get dynamicsShowAllFollowedUp => _setting.get(
    SettingBoxKey.dynamicsShowAllFollowedUp,
    defaultValue: false,
  );

  static bool get enableShowDanmaku =>
      _setting.get(SettingBoxKey.enableShowDanmaku, defaultValue: true);

  static bool get enableShowLiveDanmaku =>
      _setting.get(SettingBoxKey.enableShowLiveDanmaku, defaultValue: true);

  static bool get enableQuickFav =>
      _setting.get(SettingBoxKey.enableQuickFav, defaultValue: false);

  static bool get p1080 =>
      _setting.get(SettingBoxKey.p1080, defaultValue: true);

  static int get customColor =>
      _setting.get(SettingBoxKey.customColor, defaultValue: 0);

  static bool get dynamicColor =>
      !Platform.isIOS &&
      _setting.get(SettingBoxKey.dynamicColor, defaultValue: true);

  static bool get autoClearCache =>
      _setting.get(SettingBoxKey.autoClearCache, defaultValue: false);

  static bool get enableSystemProxy =>
      _setting.get(SettingBoxKey.enableSystemProxy, defaultValue: false);

  static bool get enableHttp2 =>
      _setting.get(SettingBoxKey.enableHttp2, defaultValue: true);

  static ReplySortType get replySortType =>
      ReplySortType.values[_setting.get(
        SettingBoxKey.replySortType,
        defaultValue: ReplySortType.hot.index,
      )];

  static DynamicBadgeMode get dynamicBadgeMode =>
      DynamicBadgeMode.values[_setting.get(
        SettingBoxKey.dynamicBadgeMode,
        defaultValue: DynamicBadgeMode.number.index,
      )];

  static bool get enableMYBar =>
      _setting.get(SettingBoxKey.enableMYBar, defaultValue: true);

  static Transition get pageTransition =>
      Transition.values[_setting.get(
        SettingBoxKey.pageTransition,
        defaultValue: Transition.native.index,
      )];

  static bool get enableQuickDouble =>
      _setting.get(SettingBoxKey.enableQuickDouble, defaultValue: true);

  static bool get fullScreenGestureReverse =>
      _setting.get(SettingBoxKey.fullScreenGestureReverse, defaultValue: false);

  static bool get autoPiP =>
      _setting.get(SettingBoxKey.autoPiP, defaultValue: false);

  static bool get enableSponsorBlock =>
      _setting.get(SettingBoxKey.enableSponsorBlock, defaultValue: false);

  static Set<int> get danmakuBlockType => Set<int>.from(
    _setting.get(SettingBoxKey.danmakuBlockType, defaultValue: const <int>{}),
  );

  static int get danmakuWeight =>
      _setting.get(SettingBoxKey.danmakuWeight, defaultValue: 0);

  static double get danmakuShowArea =>
      _setting.get(SettingBoxKey.danmakuShowArea, defaultValue: 0.5);

  static double get danmakuOpacity =>
      _setting.get(SettingBoxKey.danmakuOpacity, defaultValue: 1.0);

  static double get danmakuFontScale => _setting.get(
    SettingBoxKey.danmakuFontScale,
    defaultValue: PlatformUtils.isMobile ? 1.0 : 1.4,
  );

  static double get danmakuDuration =>
      _setting.get(SettingBoxKey.danmakuDuration, defaultValue: 7.0);

  static double get danmakuStaticDuration =>
      _setting.get(SettingBoxKey.danmakuStaticDuration, defaultValue: 4.0);

  static double get danmakuStrokeWidth => _setting.get(
    SettingBoxKey.danmakuStrokeWidth,
    defaultValue: PlatformUtils.isMobile ? 1.5 : 2.5,
  );

  static int get danmakuFontWeight => _setting.get(
    SettingBoxKey.danmakuFontWeight,
    defaultValue: PlatformUtils.isMobile ? 5 : 6,
  );

  static bool get enableLongShowControl =>
      _setting.get(SettingBoxKey.enableLongShowControl, defaultValue: false);

  static bool get enableAi =>
      _setting.get(SettingBoxKey.enableAi, defaultValue: false);

  static bool get enableOnlineTotal =>
      _setting.get(SettingBoxKey.enableOnlineTotal, defaultValue: false);

  static bool get enableAutoEnter =>
      _setting.get(SettingBoxKey.enableAutoEnter, defaultValue: false);

  static bool get enableAutoLongPressSpeed =>
      _setting.get(SettingBoxKey.enableAutoLongPressSpeed, defaultValue: false);

  static double get playSpeedDefault =>
      _video.get(VideoBoxKey.playSpeedDefault, defaultValue: 1.0);

  static double get longPressSpeedDefault =>
      _video.get(VideoBoxKey.longPressSpeedDefault, defaultValue: 3.0);

  static bool get defaultShowComment =>
      _setting.get(SettingBoxKey.defaultShowComment, defaultValue: false);

  static bool get enableTrending =>
      _setting.get(SettingBoxKey.enableHotKey, defaultValue: true);

  static bool get enableSearchRcmd =>
      _setting.get(SettingBoxKey.enableSearchRcmd, defaultValue: true);

  static bool get enableSaveLastData =>
      _setting.get(SettingBoxKey.enableSaveLastData, defaultValue: true);

  static double get defaultToastOp =>
      _setting.get(SettingBoxKey.defaultToastOp, defaultValue: 1.0);

  static PlayRepeat get playRepeat =>
      PlayRepeat.values[_video.get(
        VideoBoxKey.playRepeat,
        defaultValue: PlayRepeat.pause.index,
      )];

  static int get cacheVideoFit =>
      _video.get(VideoBoxKey.cacheVideoFit, defaultValue: 1);

  static bool get continuePlayInBackground =>
      _setting.get(SettingBoxKey.continuePlayInBackground, defaultValue: false);

  static bool get directExitOnBack =>
      _setting.get(SettingBoxKey.directExitOnBack, defaultValue: false);

  static bool get historyPause =>
      _localCache.get(LocalCacheKey.historyPause, defaultValue: false);

  static int? get quickFavId => _setting.get(SettingBoxKey.quickFavId);

  static bool get tempPlayerConf =>
      _setting.get(SettingBoxKey.tempPlayerConf, defaultValue: false);

  static Color? get reduceLuxColor {
    final int? color = _setting.get(SettingBoxKey.reduceLuxColor);
    if (color != null && color != 0xFFFFFFFF) {
      return Color(color);
    }
    return null;
  }

  static bool get showFsScreenshotBtn =>
      _setting.get(SettingBoxKey.showFsScreenshotBtn, defaultValue: true);

  static bool get showFsLockBtn =>
      _setting.get(SettingBoxKey.showFsLockBtn, defaultValue: true);

  static bool get silentDownImg =>
      _setting.get(SettingBoxKey.silentDownImg, defaultValue: false);

  static String get buvid {
    String? buvid = _localCache.get(LocalCacheKey.buvid);
    if (buvid == null) {
      buvid = LoginUtils.generateBuvid();
      _localCache.put(LocalCacheKey.buvid, buvid);
    }
    return buvid;
  }

  static bool get showMemberShop =>
      _setting.get(SettingBoxKey.showMemberShop, defaultValue: false);

  static SuperChatType get superChatType =>
      SuperChatType.values[_setting.get(
        SettingBoxKey.superChatType,
        defaultValue: SuperChatType.valid.index,
      )];

  static bool get minimizeOnExit =>
      _setting.get(SettingBoxKey.minimizeOnExit, defaultValue: true);

  static Size get windowSize {
    final List<double>? size = (_setting.get(SettingBoxKey.windowSize) as List?)
        ?.fromCast<double>();
    return size == null ? const Size(1180.0, 720.0) : Size(size[0], size[1]);
  }

  static List<double>? get windowPosition =>
      (_setting.get(SettingBoxKey.windowPosition) as List?)?.fromCast<double>();

  static bool get isWindowMaximized =>
      _setting.get(SettingBoxKey.isWindowMaximized, defaultValue: false);

  static bool get keyboardControl =>
      _setting.get(SettingBoxKey.keyboardControl, defaultValue: true);

  static bool get pauseOnMinimize =>
      _setting.get(SettingBoxKey.pauseOnMinimize, defaultValue: false);

  static bool get showWindowTitleBar =>
      _setting.get(SettingBoxKey.showWindowTitleBar, defaultValue: true);

  static double get desktopVolume =>
      _setting.get(SettingBoxKey.desktopVolume, defaultValue: 1.0);

  static SkipType get pgcSkipType =>
      SkipType.values[_setting.get(SettingBoxKey.pgcSkipType) ??
          SkipType.skipOnce.index];

  static PlayRepeat get audioPlayMode =>
      PlayRepeat.values[_setting.get(SettingBoxKey.audioPlayMode) ??
          PlayRepeat.listOrder.index];

  static bool get enablePlayAll =>
      _setting.get(SettingBoxKey.enablePlayAll, defaultValue: true);

  static bool get enableTapDm =>
      _setting.get(SettingBoxKey.enableTapDm, defaultValue: true);

  static bool get showTrayIcon =>
      _setting.get(SettingBoxKey.showTrayIcon, defaultValue: true);

  static bool get setSystemBrightness =>
      _setting.get(SettingBoxKey.setSystemBrightness, defaultValue: false);

  static String? get downloadPath => _setting.get(SettingBoxKey.downloadPath);

  static String? get liveCdnUrl => _setting.get(SettingBoxKey.liveCdnUrl);

  static bool get showBatteryLevel => _setting.get(
    SettingBoxKey.showBatteryLevel,
    defaultValue: PlatformUtils.isMobile,
  );

  static bool get autoPureBlackOnPowerSave => _setting.get(
    SettingBoxKey.autoPureBlackOnPowerSave,
    defaultValue: false,
  );

  static FollowOrderType get followOrderType =>
      FollowOrderType.values[_setting.get(
        SettingBoxKey.followOrderType,
        defaultValue: FollowOrderType.def.index,
      )];

  static bool get enableImgMenu =>
      _setting.get(SettingBoxKey.enableImgMenu, defaultValue: false);

  static bool get showDynDispute =>
      _setting.get(SettingBoxKey.showDynDispute, defaultValue: false);

  static double get touchSlopH =>
      _setting.get(SettingBoxKey.touchSlopH, defaultValue: 24.0);

  // DNS 缓存持久化
  static List<Map<String, dynamic>>? get dnsCacheData {
    final data = _localCache.get(LocalCacheKey.dnsCacheData);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return null;
  }

  static Future<void> setDnsCacheData(
    List<Map<String, dynamic>> cacheData,
  ) async {
    await _localCache.put(LocalCacheKey.dnsCacheData, cacheData);
  }

  static List<T> _mergeRecent<T>(
    Iterable<T> newest,
    Iterable<T> existing,
    int maxItems,
  ) {
    final merged = <T>[];
    final seen = <T>{};
    for (final item in newest.followedBy(existing)) {
      if (seen.add(item)) {
        merged.add(item);
      }
      if (merged.length >= maxItems) {
        break;
      }
    }
    return merged;
  }
}
