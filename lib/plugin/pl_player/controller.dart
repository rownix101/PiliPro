import 'dart:async' show StreamSubscription, Timer;
import 'dart:convert' show ascii;
import 'dart:io' show Platform, File, Directory;
import 'dart:math' show max, min;
import 'dart:ui' as ui;

import 'package:synchronized/synchronized.dart';

import 'package:PiliPro/common/constants.dart';
import 'package:PiliPro/http/init.dart';
import 'package:PiliPro/http/loading_state.dart';
import 'package:PiliPro/http/ua_type.dart';
import 'package:PiliPro/http/video.dart';
import 'package:PiliPro/models_new/common/account_type.dart';
import 'package:PiliPro/models_new/common/video/video_type.dart';
import 'package:PiliPro/models_new/user/danmaku_rule.dart';
import 'package:PiliPro/models_new/video/play/url.dart';
import 'package:PiliPro/models_new/video/video_shot/data.dart';
import 'package:PiliPro/pages/danmaku/danmaku_model.dart';
import 'package:PiliPro/pages/mine/controller.dart';
import 'package:PiliPro/pages/sponsor_block/block_mixin.dart';
import 'package:PiliPro/plugin/pl_player/models/data_source.dart';
import 'package:PiliPro/plugin/pl_player/models/data_status.dart';
import 'package:PiliPro/plugin/pl_player/models/double_tap_type.dart';
import 'package:PiliPro/plugin/pl_player/models/duration.dart';
import 'package:PiliPro/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliPro/plugin/pl_player/models/heart_beat_type.dart';
import 'package:PiliPro/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPro/plugin/pl_player/models/play_status.dart';
import 'package:PiliPro/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPro/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliPro/services/service_locator.dart';
import 'package:PiliPro/utils/accounts.dart';
import 'package:PiliPro/utils/extension/box_ext.dart';
import 'package:PiliPro/utils/extension/num_ext.dart';
import 'package:PiliPro/utils/extension/string_ext.dart';
import 'package:PiliPro/utils/feed_back.dart';
import 'package:PiliPro/utils/image_utils.dart';
import 'package:PiliPro/utils/page_utils.dart';
import 'package:PiliPro/utils/path_utils.dart';
import 'package:PiliPro/utils/platform_utils.dart';
import 'package:PiliPro/utils/storage.dart';
import 'package:PiliPro/utils/storage_key.dart';
import 'package:PiliPro/utils/storage_pref.dart';
import 'package:PiliPro/utils/utils.dart';
import 'package:archive/archive.dart' show getCrc32;
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:dio/dio.dart' show Options;
import 'package:easy_debounce/easy_throttle.dart';
import 'package:floating/floating.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, HapticFeedback, Uint8List;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'package:PiliPro/plugin/native_player/native_player.dart';
export 'package:PiliPro/plugin/native_player/native_player.dart' show SubtitleTrack;
import 'package:path/path.dart' as path;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

/// 播放列表循环模式 (从 media_kit 迁移)
enum PlaylistMode {
  /// 不循环
  none,
  /// 单曲循环
  single,
  /// 列表循环
  loop,
}

/// 字幕视图配置 (从 media_kit 迁移)
class SubtitleViewConfiguration {
  final TextStyle style;
  final TextStyle? strokeStyle;
  final EdgeInsets padding;
  final double textScaleFactor;

  const SubtitleViewConfiguration({
    required this.style,
    this.strokeStyle,
    required this.padding,
    required this.textScaleFactor,
  });
}

class PlPlayerController with BlockConfigMixin {
  NativePlayer? _nativePlayer;

  // 添加一个私有静态变量来保存实例
  static PlPlayerController? _instance;

  // 用于保护 dispose 方法的锁，防止并发调用
  final _disposeLock = Lock();

  // 标记是否已释放，防止重复释放
  bool _isDisposed = false;

  // 流事件  监听播放状态变化
  // StreamSubscription? _playerEventSubs;

  /// [playerStatus] has a [status] observable
  final playerStatus = PlPlayerStatus(PlayerStatus.playing);

  ///
  final Rx<DataStatus> dataStatus = Rx(DataStatus.none);

  // bool controlsEnabled = false;

  /// 响应数据
  /// 带有Seconds的变量只在秒数更新时更新，以避免频繁触发重绘
  // 播放位置
  Duration position = Duration.zero;
  final RxInt positionSeconds = 0.obs;

  /// 进度条位置
  Duration sliderPosition = Duration.zero;
  final RxInt sliderPositionSeconds = 0.obs;
  // 展示使用
  final Rx<Duration> sliderTempPosition = Rx(Duration.zero);

  /// 视频时长
  final Rx<Duration> duration = Rx(Duration.zero);

  /// 视频缓冲
  final Rx<Duration> buffered = Rx(Duration.zero);
  final RxInt bufferedSeconds = 0.obs;

  int _playerCount = 0;

  late double lastPlaybackSpeed = 1.0;
  final RxDouble _playbackSpeed = Pref.playSpeedDefault.obs;
  late final RxDouble _longPressSpeed = Pref.longPressSpeedDefault.obs;

  /// 音量控制条
  final RxDouble volume = RxDouble(
    PlatformUtils.isDesktop ? Pref.desktopVolume : 1.0,
  );
  final setSystemBrightness = Pref.setSystemBrightness;

  /// 亮度控制条
  final RxDouble brightness = (-1.0).obs;

  /// 是否展示控制条
  final RxBool showControls = false.obs;

  /// 亮度控制条展示/隐藏
  final RxBool showBrightnessStatus = false.obs;

  /// 是否长按倍速
  final RxBool longPressStatus = false.obs;

  /// 屏幕锁 为true时，关闭控制栏
  final RxBool controlsLock = false.obs;

  /// 全屏状态
  final RxBool isFullScreen = false.obs;
  // 默认投稿视频格式
  bool isLive = false;

  bool _isVertical = false;

  /// 视频比例
  final Rx<VideoFitType> videoFit = Rx(VideoFitType.contain);

  StreamSubscription<DataStatus>? _dataListenerForVideoFit;
  StreamSubscription<DataStatus>? _dataListenerForEnterFullScreen;

  void _stopListenerForVideoFit() {
    _dataListenerForVideoFit?.cancel();
    _dataListenerForVideoFit = null;
  }

  void _stopListenerForEnterFullScreen() {
    _dataListenerForEnterFullScreen?.cancel();
    _dataListenerForEnterFullScreen = null;
  }

  /// 后台播放
  late final RxBool continuePlayInBackground =
      Pref.continuePlayInBackground.obs;

  ///
  final RxBool isSliderMoving = false.obs;

  bool _autoPlay = false;

  // 记录历史记录
  int? _aid;
  String? _bvid;
  int? cid;
  int? _epid;
  int? _seasonId;
  int? _pgcType;
  VideoType _videoType = VideoType.ugc;
  int _heartDuration = 0;
  final Rxn<int> width = Rxn<int>();
  final Rxn<int> height = Rxn<int>();

  late final tryLook = !Accounts.get(AccountType.video).isLogin && Pref.p1080;

  late DataSource dataSource;

  Timer? _timer;
  Timer? _timerForSeek;

  Box setting = GStorage.setting;

  // final Durations durations;

  String get bvid => _bvid!;

  /// 视频播放速度
  double get playbackSpeed => _playbackSpeed.value;

  // 长按倍速
  double get longPressSpeed => _longPressSpeed.value;

  /// [nativePlayer] instance of NativePlayer
  NativePlayer? get nativePlayer => _nativePlayer;

  /// Current texture ID for rendering (Rx for reactive updates)
  final Rxn<int> _textureIdRx = Rxn<int>();
  int? get textureId => _textureIdRx.value;

  /// 兼容旧代码：videoPlayerController 指向 nativePlayer
  NativePlayer? get videoPlayerController => _nativePlayer;

  /// 兼容旧代码：videoController 返回 textureId
  int? get videoController => _textureIdRx.value;

  /// 释放纹理（在 dispose 前调用，确保 Texture widget 先停止渲染）
  void releaseTexture() {
    // 避免在 dispose 后调用时抛出异常
    try {
      _textureIdRx.value = null;
    } catch (_) {
      // Rx 变量可能已关闭，忽略异常
    }
    // 注意：不要在这里暂停播放器
    // 页面返回时会通过 playerInit 重新初始化，暂停会导致状态混乱
  }

  bool isMuted = false;

  /// 听视频
  late final RxBool onlyPlayAudio = false.obs;

  /// 镜像
  late final RxBool flipX = false.obs;

  late final RxBool flipY = false.obs;

  final RxBool isBuffering = true.obs;

  /// 全屏方向
  bool get isVertical => _isVertical;

  /// 弹幕开关
  late final RxBool _enableShowDanmaku = Pref.enableShowDanmaku.obs;
  late final RxBool _enableShowLiveDanmaku = Pref.enableShowLiveDanmaku.obs;
  final RxBool _enableShowDanmakuActive = Pref.enableShowDanmaku.obs;
  RxBool get enableShowDanmaku => _enableShowDanmakuActive;

  late final bool autoPiP = Pref.autoPiP;
  bool get isPipMode =>
      (Platform.isAndroid && Floating().isPipMode) ||
      (PlatformUtils.isDesktop && isDesktopPip);
  late bool isDesktopPip = false;
  late Rect _lastWindowBounds;

  late final showWindowTitleBar = Pref.showWindowTitleBar;
  late final RxBool isAlwaysOnTop = false.obs;
  Future<void> setAlwaysOnTop(bool value) {
    isAlwaysOnTop.value = value;
    return windowManager.setAlwaysOnTop(value);
  }

  Future<void> exitDesktopPip() {
    isDesktopPip = false;
    return Future.wait([
      if (showWindowTitleBar)
        windowManager.setTitleBarStyle(TitleBarStyle.normal),
      windowManager.setMinimumSize(const Size(400, 700)),
      windowManager.setBounds(_lastWindowBounds),
      setAlwaysOnTop(false),
      windowManager.setAspectRatio(0),
    ]);
  }

  Future<void> enterDesktopPip() async {
    if (isFullScreen.value) return;

    isDesktopPip = true;

    _lastWindowBounds = await windowManager.getBounds();

    if (showWindowTitleBar) {
      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }

    late final Size size;
    final w = width.value ?? 16;
    final h = height.value ?? 9;
    if (h > w) {
      size = Size(280.0, 280.0 * h / w);
    } else {
      size = Size(280.0 * w / h, 280.0);
    }

    await windowManager.setMinimumSize(size);
    setAlwaysOnTop(true);
    windowManager
      ..setSize(size)
      ..setAspectRatio(w / h);
  }

  void toggleDesktopPip() {
    if (isDesktopPip) {
      exitDesktopPip();
    } else {
      enterDesktopPip();
    }
  }

  late bool _shouldSetPip = false;

  bool get _isCurrVideoPage {
    final routing = Get.routing;
    if (routing.route is! GetPageRoute) {
      return false;
    }
    final currentRoute = routing.current;
    return currentRoute.startsWith('/video') ||
        currentRoute.startsWith('/liveRoom');
  }

  bool get _isPreviousVideoPage {
    final previousRoute = Get.previousRoute;
    return previousRoute.startsWith('/video') ||
        previousRoute.startsWith('/liveRoom');
  }

  void enterPip({bool isAuto = false}) {
    if (_nativePlayer != null) {
      controls = false;
      PageUtils.enterPip(
        isAuto: isAuto,
        width: width.value,
        height: height.value,
      );
    }
  }

  void _disableAutoEnterPipIfNeeded() {
    if (!_isPreviousVideoPage) {
      _disableAutoEnterPip();
    }
  }

  void _disableAutoEnterPip() {
    if (_shouldSetPip) {
      Utils.channel.invokeMethod('setPipAutoEnterEnabled', {
        'autoEnable': false,
      });
    }
  }

  // 弹幕相关配置
  late final enableTapDm = PlatformUtils.isMobile && Pref.enableTapDm;
  late RuleFilter filters = Pref.danmakuFilterRule;
  // 关联弹幕控制器
  DanmakuController<DanmakuExtra>? danmakuController;
  bool showDanmaku = true;
  Set<int> dmState = <int>{};
  late final mergeDanmaku = Pref.mergeDanmaku;
  late final String midHash = getCrc32(
    ascii.encode(Accounts.main.mid.toString()),
    0,
  ).toRadixString(16);
  late final RxDouble danmakuOpacity = Pref.danmakuOpacity.obs;

  late List<double> speedList = Pref.speedList;
  late bool enableAutoLongPressSpeed = Pref.enableAutoLongPressSpeed;
  late final showControlDuration = Pref.enableLongShowControl
      ? const Duration(seconds: 30)
      : const Duration(seconds: 3);
  // 字幕
  late double subtitleFontScale = Pref.subtitleFontScale;
  late double subtitleFontScaleFS = Pref.subtitleFontScaleFS;
  late int subtitlePaddingH = Pref.subtitlePaddingH;
  late int subtitlePaddingB = Pref.subtitlePaddingB;
  late double subtitleBgOpacity = Pref.subtitleBgOpacity;
  final bool showVipDanmaku = Pref.showVipDanmaku; // loop unswitching
  late double subtitleStrokeWidth = Pref.subtitleStrokeWidth;
  late int subtitleFontWeight = Pref.subtitleFontWeight;

  // settings
  late final showFSActionItem = Pref.showFSActionItem;
  late final enableShrinkVideoSize = Pref.enableShrinkVideoSize;
  late final darkVideoPage = Pref.darkVideoPage;
  late final enableSlideVolumeBrightness = Pref.enableSlideVolumeBrightness;
  late final enableSlideFS = Pref.enableSlideFS;
  late final enableDragSubtitle = Pref.enableDragSubtitle;
  late final fastForBackwardDuration = Duration(
    seconds: Pref.fastForBackwardDuration,
  );

  late final horizontalSeasonPanel = Pref.horizontalSeasonPanel;
  late final preInitPlayer = Pref.preInitPlayer;
  late final showRelatedVideo = Pref.showRelatedVideo;
  late final showVideoReply = Pref.showVideoReply;
  late final showBangumiReply = Pref.showBangumiReply;
  late final reverseFromFirst = Pref.reverseFromFirst;
  late final horizontalPreview = Pref.horizontalPreview;
  late final showDmChart = Pref.showDmChart;
  late final showViewPoints = Pref.showViewPoints;
  late final showFsScreenshotBtn = Pref.showFsScreenshotBtn;
  late final showFsLockBtn = Pref.showFsLockBtn;
  late final keyboardControl = Pref.keyboardControl;

  late final bool autoExitFullscreen = Pref.autoExitFullscreen;
  late final bool autoPlayEnable = Pref.autoPlayEnable;
  late final bool enableVerticalExpand = Pref.enableVerticalExpand;
  late final bool pipNoDanmaku = Pref.pipNoDanmaku;

  late final bool tempPlayerConf = Pref.tempPlayerConf;

  late int? cacheVideoQa = PlatformUtils.isMobile ? null : Pref.defaultVideoQa;
  late int cacheAudioQa = Pref.defaultAudioQa;
  bool enableHeart = true;



  late final progressType = Pref.btmProgressBehavior;
  late final enableQuickDouble = Pref.enableQuickDouble;
  late final fullScreenGestureReverse = Pref.fullScreenGestureReverse;

  late final isRelative = Pref.useRelativeSlide;
  late final offset = isRelative
      ? Pref.sliderDuration / 100
      : Pref.sliderDuration * 1000;

  num get sliderScale =>
      isRelative ? duration.value.inMilliseconds * offset : offset;

  // 播放顺序相关
  late PlayRepeat playRepeat = Pref.playRepeat;

  TextStyle get subTitleStyle => TextStyle(
    height: 1.5,
    fontSize:
        16 * (isFullScreen.value ? subtitleFontScaleFS : subtitleFontScale),
    letterSpacing: 0.1,
    wordSpacing: 0.1,
    color: Colors.white,
    fontWeight: FontWeight.values[subtitleFontWeight],
    backgroundColor: subtitleBgOpacity == 0
        ? null
        : Colors.black.withValues(alpha: subtitleBgOpacity),
  );

  late final Rx<SubtitleViewConfiguration> subtitleConfig = _getSubConfig.obs;

  SubtitleViewConfiguration get _getSubConfig {
    final subTitleStyle = this.subTitleStyle;
    return SubtitleViewConfiguration(
      style: subTitleStyle,
      strokeStyle: subtitleBgOpacity == 0
          ? subTitleStyle.copyWith(
              color: null,
              background: null,
              backgroundColor: null,
              foreground: Paint()
                ..color = Colors.black
                ..style = PaintingStyle.stroke
                ..strokeWidth = subtitleStrokeWidth,
            )
          : null,
      padding: EdgeInsets.only(
        left: subtitlePaddingH.toDouble(),
        right: subtitlePaddingH.toDouble(),
        bottom: subtitlePaddingB.toDouble(),
      ),
      textScaleFactor: 1,
    );
  }

  void updateSubtitleStyle() {
    subtitleConfig.value = _getSubConfig;
  }

  void onUpdatePadding(EdgeInsets padding) {
    subtitlePaddingB = padding.bottom.round().clamp(0, 200);
    putSubtitleSettings();
  }

  void updateSliderPositionSecond() {
    int newSecond = sliderPosition.inSeconds;
    if (sliderPositionSeconds.value != newSecond) {
      sliderPositionSeconds.value = newSecond;
    }
  }

  void updatePositionSecond() {
    int newSecond = position.inSeconds;
    if (positionSeconds.value != newSecond) {
      positionSeconds.value = newSecond;
    }
  }

  void updateBufferedSecond() {
    int newSecond = buffered.value.inSeconds;
    if (bufferedSeconds.value != newSecond) {
      bufferedSeconds.value = newSecond;
    }
  }

  static PlPlayerController? get instance => _instance;

  static bool instanceExists() {
    return _instance != null;
  }

  static void setPlayCallBack(Future<void>? Function()? playCallBack) {
    _playCallBack = playCallBack;
  }

  static Future<void>? Function()? _playCallBack;

  static Future<void>? playIfExists() {
    // await _instance?.play(repeat: repeat, hideControls: hideControls);
    return _playCallBack?.call();
  }

  // try to get PlayerStatus
  static PlayerStatus? getPlayerStatusIfExists() {
    return _instance?.playerStatus.value;
  }

  static Future<void> pauseIfExists({
    bool notify = true,
    bool isInterrupt = false,
  }) async {
    if (_instance?.playerStatus.isPlaying ?? false) {
      await _instance?.pause(notify: notify, isInterrupt: isInterrupt);
    }
  }

  static Future<void> seekToIfExists(
    Duration position, {
    bool isSeek = true,
  }) async {
    await _instance?.seekTo(position, isSeek: isSeek);
  }

  static double? getVolumeIfExists() {
    return _instance?.volume.value;
  }

  static Future<void> setVolumeIfExists(double volumeNew) async {
    await _instance?.setVolume(volumeNew);
  }

  Box video = GStorage.video;

  // 添加一个私有构造函数
  PlPlayerController._() {
    if (!Accounts.heartbeat.isLogin || Pref.historyPause) {
      enableHeart = false;
    }

    // 设置弹幕开关双向同步
    // 当 _enableShowDanmakuActive 改变时，同步到对应的源 Rx
    ever(_enableShowDanmakuActive, (value) {
      if (isLive) {
        _enableShowLiveDanmaku.value = value;
      } else {
        _enableShowDanmaku.value = value;
      }
    });
    // 当源 Rx 改变时，同步到 _enableShowDanmakuActive
    ever(_enableShowDanmaku, (value) {
      if (!isLive) _enableShowDanmakuActive.value = value;
    });
    ever(_enableShowLiveDanmaku, (value) {
      if (isLive) _enableShowDanmakuActive.value = value;
    });

    if (Platform.isAndroid && autoPiP) {
      Utils.sdkInt.then((sdkInt) {
        if (sdkInt < 36) {
          Utils.channel.setMethodCallHandler((call) async {
            if (call.method == 'onUserLeaveHint') {
              if (playerStatus.isPlaying && _isCurrVideoPage) {
                enterPip();
              }
            }
          });
        } else {
          _shouldSetPip = true;
        }
      });
    }
  }

  // 获取实例 传参
  static PlPlayerController getInstance({bool isLive = false}) {
    // 如果实例尚未创建，则创建一个新实例
    _instance ??= PlPlayerController._();
    _instance!
      ..isLive = isLive
      .._enableShowDanmakuActive.value = isLive
          ? _instance!._enableShowLiveDanmaku.value
          : _instance!._enableShowDanmaku.value
      .._playerCount += 1;
    return _instance!;
  }

  bool _processing = false;
  bool get processing => _processing;

  // offline
  bool isFileSource = false;
  String? dirPath;
  String? typeTag;
  int? mediaType;

  // 初始化资源
  Future<void> setDataSource(
    DataSource dataSource, {
    bool isLive = false,
    bool autoplay = true,
    // 默认不循环
    PlaylistMode looping = PlaylistMode.none,
    // 初始化播放位置
    Duration? seekTo,
    // 初始化播放速度
    double speed = 1.0,
    int? width,
    int? height,
    Duration? duration,
    // 方向
    bool? isVertical,
    // 记录历史记录
    int? aid,
    String? bvid,
    int? cid,
    int? epid,
    int? seasonId,
    int? pgcType,
    VideoType? videoType,
    VoidCallback? onInit,
    Volume? volume,
    String? dirPath,
    String? typeTag,
    int? mediaType,
  }) async {
    try {
      this.dirPath = dirPath;
      this.typeTag = typeTag;
      this.mediaType = mediaType;
      isFileSource = dataSource.type == DataSourceType.file;
      _processing = true;
      this.isLive = isLive;
      _enableShowDanmakuActive.value = isLive
          ? _enableShowLiveDanmaku.value
          : _enableShowDanmaku.value;
      _videoType = videoType ?? VideoType.ugc;
      this.width.value = width;
      this.height.value = height;
      this.dataSource = dataSource;
      _autoPlay = autoplay;
      // 初始化视频倍速
      // _playbackSpeed.value = speed;
      // 初始化数据加载状态
      dataStatus.value = DataStatus.loading;
      // 初始化全屏方向
      _isVertical = isVertical ?? false;
      _aid = aid;
      _bvid = bvid;
      this.cid = cid;
      _epid = epid;
      _seasonId = seasonId;
      _pgcType = pgcType;

      if (showSeekPreview) {
        _clearPreview();
      }
      cancelLongPressTimer();
      if (_nativePlayer != null) {
        await pause(notify: false);
      }

      if (_playerCount == 0) {
        return;
      }
      // 配置Player 音轨、字幕等等
      _nativePlayer = await _createVideoController(
        dataSource,
        seekTo,
      );
      // 获取视频时长 00:00
      this.duration.value = duration ?? Duration.zero;
      position = buffered.value = sliderPosition = seekTo ?? Duration.zero;
      updatePositionSecond();
      updateSliderPositionSecond();
      updateBufferedSecond();
      // 数据加载完成
      dataStatus.value = DataStatus.loaded;

      // listen the video player events
      startListeners();
      await _initializePlayer();
      onInit?.call();
    } catch (err, stackTrace) {
      dataStatus.value = DataStatus.error;
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
        debugPrint('plPlayer err:  $err');
      }
    } finally {
      _processing = false;
    }
  }

  String? shadersDirPath;
  Future<String> get copyShadersToExternalDirectory async {
    if (shadersDirPath != null) {
      return shadersDirPath!;
    }

    final dir = Directory(path.join(appSupportDirPath, 'anime_shaders'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final shaderFilesPath =
        (Constants.mpvAnime4KShaders + Constants.mpvAnime4KShadersLite)
            .map((e) => 'assets/shaders/$e')
            .toList();

    for (final filePath in shaderFilesPath) {
      final fileName = filePath.split('/').last;
      final targetFile = File(path.join(dir.path, fileName));
      if (targetFile.existsSync()) {
        continue;
      }

      try {
        final data = await rootBundle.load(filePath);
        final List<int> bytes = data.buffer.asUint8List();
        await targetFile.writeAsBytes(bytes);
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    }
    return shadersDirPath = dir.path;
  }

  late final isAnim = _pgcType == 1 || _pgcType == 4;

  static final loudnormRegExp = RegExp('loudnorm=([^,]+)');

  // 配置播放器
  Future<NativePlayer> _createVideoController(
    DataSource dataSource,
    Duration? seekTo,
  ) async {
    // 每次配置时先移除监听
    removeListeners();
    isBuffering.value = false;
    buffered.value = Duration.zero;
    _heartDuration = 0;
    position = Duration.zero;
    // 初始化时清空弹幕，防止上次重叠
    danmakuController?.clear();

    final player = _nativePlayer ??= NativePlayer();

    // 音轨
    final String? audioUrl;
    if (isFileSource) {
      audioUrl = onlyPlayAudio.value || mediaType == 1
          ? null
          : path.join(dirPath!, typeTag!, PathUtils.audioNameType2);
    } else if (dataSource.audioSource?.isNotEmpty == true) {
      audioUrl = dataSource.audioSource;
    } else {
      audioUrl = null;
    }

    late final String videoUrl;
    if (isFileSource) {
      videoUrl = path.join(
        dirPath!,
        typeTag!,
        mediaType == 1
            ? PathUtils.videoNameType1
            : onlyPlayAudio.value
            ? PathUtils.audioNameType2
            : PathUtils.videoNameType2,
      );
    } else {
      videoUrl = dataSource.videoSource!;
    }

    _textureIdRx.value = await player.create(
      videoUrl: videoUrl,
      audioUrl: audioUrl,
      headers: dataSource.httpHeaders,
    );

    if (seekTo != null) {
      await player.seekTo(seekTo);
    }

    return player;
  }

  Future<bool> refreshPlayer() async {
    if (isFileSource) {
      return true;
    }
    if (_nativePlayer == null) {
      return false;
    }
    if (dataSource.videoSource.isNullOrEmpty) {
      SmartDialog.showToast('视频源为空，请重新进入本页面');
      return false;
    }
    if (!isLive && dataSource.audioSource.isNullOrEmpty) {
      SmartDialog.showToast('音频源为空');
    }
    await _nativePlayer!.dispose();
    _textureIdRx.value = await _nativePlayer!.create(
      videoUrl: dataSource.videoSource!,
      audioUrl: isLive ? null : dataSource.audioSource,
      headers: dataSource.httpHeaders,
    );
    await _nativePlayer!.seekTo(position);
    await _nativePlayer!.play();
    return true;
  }

  // 开始播放
  Future<void> _initializePlayer() async {
    if (_instance == null) return;
    // 设置倍速
    if (isLive) {
      await setPlaybackSpeed(1.0);
    } else {
      if (true) { // native player always has a rate to set
        await setPlaybackSpeed(_playbackSpeed.value);
      }
    }
    getVideoFit();
    // }

    // 跳转播放
    // if (seekTo != Duration.zero) {
    //   await this.seekTo(seekTo);
    // }

    // 自动播放
    if (_autoPlay) {
      playIfExists();
      // await play(duration: duration);
    }
  }

  late final bool enableAutoEnter = Pref.enableAutoEnter;
  Future<void>? autoEnterFullscreen() {
    if (enableAutoEnter) {
      return Future.delayed(const Duration(milliseconds: 500), () {
        if (!dataStatus.loaded) {
          _stopListenerForEnterFullScreen();
          _dataListenerForEnterFullScreen = dataStatus.listen((status) {
            if (status == DataStatus.loaded) {
              _stopListenerForEnterFullScreen();
              triggerFullScreen(status: true);
            }
          });
        } else {
          return triggerFullScreen(status: true);
        }
      });
    }
    return null;
  }

  Set<StreamSubscription> subscriptions = {};
  final Set<Function(Duration position)> _positionListeners = {};
  final Set<Function(PlayerStatus status)> _statusListeners = {};

  /// 播放事件监听
  void startListeners() {
    final player = _nativePlayer;
    if (player == null) return;
    // 如果已被释放，不添加监听器
    if (_isDisposed || _playerCount == 0) return;
    subscriptions = {
      player.events.listen((event) {
        switch (event.type) {
          case 'isPlaying':
            final isPlaying = event.isPlaying ?? false;
            WakelockPlus.toggle(enable: isPlaying);
            if (isPlaying) {
              if (_shouldSetPip) {
                if (_isCurrVideoPage) {
                  enterPip(isAuto: true);
                } else {
                  _disableAutoEnterPip();
                }
              }
              playerStatus.value = PlayerStatus.playing;
            } else {
              _disableAutoEnterPip();
              playerStatus.value = PlayerStatus.paused;
            }
            videoPlayerServiceHandler?.onStatusChange(
              playerStatus.value,
              isBuffering.value,
              isLive,
            );
            for (final element in _statusListeners) {
              element(isPlaying ? PlayerStatus.playing : PlayerStatus.paused);
            }
            if (positionSeconds.value != 0) {
              makeHeartBeat(positionSeconds.value, type: HeartBeatType.status);
            }
            break;
          case 'playbackState':
            final state = event.state;
            if (state == 'ended') {
              playerStatus.value = PlayerStatus.completed;
              for (final element in _statusListeners) {
                element(PlayerStatus.completed);
              }
              makeHeartBeat(positionSeconds.value, type: HeartBeatType.completed);
            } else if (state == 'buffering') {
              isBuffering.value = true;
              videoPlayerServiceHandler?.onStatusChange(
                playerStatus.value,
                true,
                isLive,
              );
            } else if (state == 'ready') {
              isBuffering.value = false;
              videoPlayerServiceHandler?.onStatusChange(
                playerStatus.value,
                false,
                isLive,
              );
            }
            break;
          case 'position':
            if (event.position != null) {
              position = event.position!;
              updatePositionSecond();
              if (!isSliderMoving.value) {
                sliderPosition = event.position!;
                updateSliderPositionSecond();
              }
              for (final element in _positionListeners) {
                element(event.position!);
              }
              makeHeartBeat(event.position!.inSeconds);
            }
            if (event.duration != null) {
              duration.value = event.duration!;
            }
            if (event.buffered != null) {
              buffered.value = event.buffered!;
              updateBufferedSecond();
            }
            break;
          case 'error':
            final error = event.error ?? 'Unknown error';
            if (isFileSource && error.contains('open')) {
              break;
            }
            if (isLive) {
              Future.delayed(const Duration(milliseconds: 3000), refreshPlayer);
              break;
            }
            EasyThrottle.throttle(
              'nativePlayer.error',
              const Duration(milliseconds: 10000),
              () {
                Future.delayed(const Duration(milliseconds: 3000), () async {
                  if (isBuffering.value && buffered.value == Duration.zero) {
                    SmartDialog.showToast(
                      '视频链接打开失败，重试中',
                      displayTime: const Duration(milliseconds: 500),
                    );
                    if (!await refreshPlayer()) {
                      if (kDebugMode) debugPrint('refresh failed');
                    }
                  }
                });
              },
            );
            break;
          case 'videoSize':
            if (event.videoWidth != null && event.videoHeight != null) {
              width.value = event.videoWidth;
              height.value = event.videoHeight;
            }
            break;
        }
      }),
      // 媒体通知监听已移至下方（带异常保护）
    };
    // 使用 try-catch 保护媒体通知监听，避免 Rx 变量已关闭时抛出异常
    if (videoPlayerServiceHandler != null) {
      try {
        subscriptions.add(
          playerStatus.listen((PlayerStatus event) {
            videoPlayerServiceHandler!.onStatusChange(
              event,
              isBuffering.value,
              isLive,
            );
          }),
        );
      } catch (_) {
        // Rx 变量可能已关闭，忽略
      }
      try {
        subscriptions.add(
          positionSeconds.listen((int event) {
            videoPlayerServiceHandler!.onPositionChange(Duration(seconds: event));
          }),
        );
      } catch (_) {
        // Rx 变量可能已关闭，忽略
      }
    }
  }

  /// 移除事件监听
  Future<void> removeListeners() async {
    final subs = subscriptions.toList();
    subscriptions.clear();
    for (final subscription in subs) {
      try {
        await subscription.cancel();
      } catch (e) {
        // 忽略已关闭的订阅取消错误
      }
    }
  }

  /// 跳转至指定位置
  Future<void> seekTo(Duration position, {bool isSeek = true}) async {
    // if (position >= duration.value) {
    //   position = duration.value - const Duration(milliseconds: 100);
    // }
    if (_playerCount == 0) {
      return;
    }
    if (position < Duration.zero) {
      position = Duration.zero;
    }
    this.position = position;
    updatePositionSecond();
    _heartDuration = position.inSeconds;
    if (duration.value.inSeconds != 0) {
      if (isSeek) {
        /// 拖动进度条调节时，等待短暂时间防止抖动
        await Future.delayed(const Duration(milliseconds: 100));
      }
      danmakuController?.clear();
      try {
        await _nativePlayer?.seekTo(position);
      } catch (e) {
        if (kDebugMode) debugPrint('seek failed: $e');
      }
      // if (playerStatus.stopped) {
      //   play();
      // }
    } else {
      // if (kDebugMode) debugPrint('seek duration else');
      _timerForSeek?.cancel();
      _timerForSeek = Timer.periodic(const Duration(milliseconds: 200), (
        Timer t,
      ) async {
        //_timerForSeek = null;
        if (_playerCount == 0) {
          _timerForSeek?.cancel();
          _timerForSeek = null;
        } else if (duration.value != Duration.zero) {
          try {
            await Future.delayed(const Duration(milliseconds: 100));
            danmakuController?.clear();
            await _nativePlayer?.seekTo(position);
          } catch (e) {
            if (kDebugMode) debugPrint('seek failed: $e');
          }
          // if (playerStatus.isPaused) {
          //   play();
          // }
          t.cancel();
          _timerForSeek = null;
        }
      });
    }
  }

  /// 设置倍速
  Future<void> setPlaybackSpeed(double speed) async {
    lastPlaybackSpeed = playbackSpeed;

    await _nativePlayer?.setSpeed(speed);
    try {
      _playbackSpeed.value = speed;
    } catch (_) {
      // Rx 变量可能已关闭，忽略异常
    }
    if (danmakuController != null) {
      try {
        DanmakuOption currentOption = danmakuController!.option;
        double defaultDuration = currentOption.duration * lastPlaybackSpeed;
        double defaultStaticDuration =
            currentOption.staticDuration * lastPlaybackSpeed;
        DanmakuOption updatedOption = currentOption.copyWith(
          duration: defaultDuration / speed,
          staticDuration: defaultStaticDuration / speed,
        );
        danmakuController!.updateOption(updatedOption);
      } catch (_) {}
    }
  }

  // 还原默认速度
  double playSpeedDefault = Pref.playSpeedDefault;
  Future<void> setDefaultSpeed() async {
    await _nativePlayer?.setSpeed(playSpeedDefault);
    _playbackSpeed.value = playSpeedDefault;
  }

  /// 播放视频
  Future<void> play({bool repeat = false, bool hideControls = true}) async {
    if (_playerCount == 0) return;
    // 播放时自动隐藏控制条
    controls = !hideControls;
    // repeat为true，将从头播放
    if (repeat) {
      // await seekTo(Duration.zero);
      await seekTo(Duration.zero, isSeek: false);
    }

    await _nativePlayer?.play();

    audioSessionHandler?.setActive(true);

    playerStatus.value = PlayerStatus.playing;
    // screenManager.setOverlays(false);
  }

  /// 暂停播放
  Future<void> pause({bool notify = true, bool isInterrupt = false}) async {
    await _nativePlayer?.pause();
    playerStatus.value = PlayerStatus.paused;

    // 主动暂停时让出音频焦点
    if (!isInterrupt) {
      audioSessionHandler?.setActive(false);
    }
  }

  bool tripling = false;

  /// 隐藏控制条
  void hideTaskControls() {
    _timer?.cancel();
    _timer = Timer(showControlDuration, () {
      if (!isSliderMoving.value && !tripling) {
        controls = false;
      }
      _timer = null;
    });
  }

  /// 调整播放时间
  void onChangedSlider(int v) {
    sliderPosition = Duration(seconds: v);
    updateSliderPositionSecond();
  }

  void onChangedSliderStart([Duration? value]) {
    if (value != null) {
      sliderTempPosition.value = value;
    }
    isSliderMoving.value = true;
  }

  bool? cancelSeek;
  bool? hasToast;

  void onUpdatedSliderProgress(Duration value) {
    sliderTempPosition.value = value;
    sliderPosition = value;
    updateSliderPositionSecond();
  }

  void onChangedSliderEnd() {
    if (cancelSeek != true) {
      feedBack();
    }
    cancelSeek = null;
    hasToast = null;
    isSliderMoving.value = false;
    hideTaskControls();
  }

  final RxBool volumeIndicator = false.obs;
  Timer? volumeTimer;
  final RxBool volumeInterceptEventStream = false.obs;

  static final double maxVolume = PlatformUtils.isDesktop ? 2.0 : 1.0;
  Future<void> setVolume(double volume) async {
    if (this.volume.value != volume) {
      this.volume.value = volume;
      try {
        if (PlatformUtils.isDesktop) {
          _nativePlayer!.setVolume(volume);
        } else {
          FlutterVolumeController.updateShowSystemUI(false);
          await FlutterVolumeController.setVolume(volume);
        }
      } catch (err) {
        if (kDebugMode) debugPrint(err.toString());
      }
    }
    volumeIndicator.value = true;
    volumeInterceptEventStream.value = true;
    volumeTimer?.cancel();
    volumeTimer = Timer(const Duration(milliseconds: 200), () {
      volumeIndicator.value = false;
      volumeInterceptEventStream.value = false;
      if (PlatformUtils.isDesktop) {
        setting.put(SettingBoxKey.desktopVolume, volume.toPrecision(3));
      }
    });
  }

  /// Toggle Change the videofit accordingly
  void toggleVideoFit(VideoFitType value) {
    videoFit.value = value;
    video.put(VideoBoxKey.cacheVideoFit, value.index);
  }

  /// 读取fit
  int fitValue = Pref.cacheVideoFit;
  Future<void> getVideoFit() async {
    var attr = VideoFitType.values[fitValue];
    // 由于none与scaleDown涉及视频原始尺寸，需要等待视频加载后再设置，否则尺寸会变为0，出现错误;
    if (attr == VideoFitType.none || attr == VideoFitType.scaleDown) {
      if (buffered.value == Duration.zero) {
        attr = VideoFitType.contain;
        _stopListenerForVideoFit();
        _dataListenerForVideoFit = dataStatus.listen((status) {
          if (status == DataStatus.loaded) {
            _stopListenerForVideoFit();
            final attr = VideoFitType.values[fitValue];
            if (attr == VideoFitType.none || attr == VideoFitType.scaleDown) {
              videoFit.value = attr;
            }
          }
        });
      }
      // fill不应该在竖屏视频生效
    } else if (attr == VideoFitType.fill && isVertical) {
      attr = VideoFitType.contain;
    }
    videoFit.value = attr;
  }

  /// 设置后台播放
  void setBackgroundPlay(bool val) {
    videoPlayerServiceHandler?.enableBackgroundPlay = val;
    if (!tempPlayerConf) {
      setting.put(SettingBoxKey.enableBackgroundPlay, val);
    }
  }

  set controls(bool visible) {
    showControls.value = visible;
    _timer?.cancel();
    if (visible) {
      hideTaskControls();
    }
  }

  Timer? longPressTimer;
  void cancelLongPressTimer() {
    longPressTimer?.cancel();
    longPressTimer = null;
  }

  /// 设置长按倍速状态 live模式下禁用
  Future<void> setLongPressStatus(bool val) async {
    if (isLive) {
      return;
    }
    if (controlsLock.value) {
      return;
    }
    if (longPressStatus.value == val) {
      return;
    }
    if (val) {
      if (playerStatus.isPlaying) {
        longPressStatus.value = val;
        HapticFeedback.lightImpact();
        await setPlaybackSpeed(
          enableAutoLongPressSpeed ? playbackSpeed * 2 : longPressSpeed,
        );
      }
    } else {
      // if (kDebugMode) debugPrint('$playbackSpeed');
      longPressStatus.value = val;
      await setPlaybackSpeed(lastPlaybackSpeed);
    }
  }

  bool get _isCompleted =>
      playerStatus.value == PlayerStatus.completed ||
      (duration.value - position).inMilliseconds <= 50;

  // 双击播放、暂停
  Future<void> onDoubleTapCenter() async {
    if (!isLive && _isCompleted) {
      await _nativePlayer?.seekTo(Duration.zero);
      await _nativePlayer?.play();
    } else {
      if (playerStatus.isPlaying) {
        await pause();
      } else {
        await play();
      }
    }
  }

  final RxBool mountSeekBackwardButton = false.obs;
  final RxBool mountSeekForwardButton = false.obs;

  void onDoubleTapSeekBackward() {
    mountSeekBackwardButton.value = true;
  }

  void onDoubleTapSeekForward() {
    mountSeekForwardButton.value = true;
  }

  void onForward(Duration duration) {
    onForwardBackward(position + duration);
  }

  void onBackward(Duration duration) {
    onForwardBackward(position - duration);
  }

  void onForwardBackward(Duration duration) {
    seekTo(
      duration.clamp(Duration.zero, this.duration.value),
      isSeek: false,
    ).whenComplete(play);
  }

  void doubleTapFuc(DoubleTapType type) {
    if (!enableQuickDouble) {
      onDoubleTapCenter();
      return;
    }
    switch (type) {
      case DoubleTapType.left:
        // 双击左边区域 👈
        onDoubleTapSeekBackward();
        break;
      case DoubleTapType.center:
        onDoubleTapCenter();
        break;
      case DoubleTapType.right:
        // 双击右边区域 👈
        onDoubleTapSeekForward();
        break;
    }
  }

  /// 关闭控制栏
  void onLockControl(bool val) {
    feedBack();
    controlsLock.value = val;
    if (!val && showControls.value) {
      showControls.refresh();
    }
    controls = !val;
  }

  void toggleFullScreen(bool val) {
    isFullScreen.value = val;
    updateSubtitleStyle();
  }

  late bool isManualFS = true;
  late final FullScreenMode mode = Pref.fullScreenMode;
  late final horizontalScreen = Pref.horizontalScreen;

  // 全屏
  bool fsProcessing = false;
  Future<void> triggerFullScreen({
    bool status = true,
    bool inAppFullScreen = false,
    bool isManualFS = true,
    FullScreenMode? mode,
  }) async {
    if (isDesktopPip) return;
    if (isFullScreen.value == status) return;

    if (fsProcessing) {
      return;
    }
    fsProcessing = true;
    try {
      mode ??= this.mode;
      this.isManualFS = isManualFS;

      if (status) {
        if (PlatformUtils.isMobile) {
          hideStatusBar();
          if (mode == FullScreenMode.none) {
            return;
          }
          if (mode == FullScreenMode.gravity) {
            await fullAutoModeForceSensor();
            return;
          }
          late final size = MediaQuery.sizeOf(Get.context!);
          if ((mode == FullScreenMode.vertical ||
              (mode == FullScreenMode.auto && isVertical) ||
              (mode == FullScreenMode.ratio &&
                  (isVertical || size.height / size.width < kScreenRatio)))) {
            await verticalScreenForTwoSeconds();
          } else {
            await landscape();
          }
        } else {
          await enterDesktopFullscreen(inAppFullScreen: inAppFullScreen);
        }
      } else {
        if (PlatformUtils.isMobile) {
          showStatusBar();
          if (mode == FullScreenMode.none) {
            return;
          }
          if (!horizontalScreen) {
            await verticalScreenForTwoSeconds();
          } else {
            await autoScreen();
          }
        } else {
          await exitDesktopFullscreen();
        }
      }
    } finally {
      toggleFullScreen(status);
      fsProcessing = false;
    }
  }

  void addPositionListener(Function(Duration position) listener) {
    if (_playerCount == 0) return;
    _positionListeners.add(listener);
  }

  void removePositionListener(Function(Duration position) listener) =>
      _positionListeners.remove(listener);

  void addStatusLister(Function(PlayerStatus status) listener) {
    if (_playerCount == 0) return;
    _statusListeners.add(listener);
  }

  void removeStatusLister(Function(PlayerStatus status) listener) =>
      _statusListeners.remove(listener);

  /// 截屏 - 使用RepaintBoundary方式由view层实现
  /// 此方法保留为兼容接口，但不再直接从播放器截屏
  Future<Uint8List?> screenshot() async {
    // Native player does not support direct screenshot.
    // Use RepaintBoundary.toImage() in the view layer instead.
    return null;
  }

  // 记录播放记录
  Future<void>? makeHeartBeat(
    int progress, {
    HeartBeatType type = HeartBeatType.playing,
    bool isManual = false,
    dynamic aid,
    dynamic bvid,
    dynamic cid,
    dynamic epid,
    dynamic seasonId,
    dynamic pgcType,
    VideoType? videoType,
  }) {
    if (isLive) {
      return null;
    }
    if (!enableHeart || MineController.anonymity.value || progress == 0) {
      return null;
    } else if (playerStatus.isPaused) {
      if (!isManual) {
        return null;
      }
    }
    bool isComplete =
        playerStatus.isCompleted || type == HeartBeatType.completed;
    if ((duration.value - position).inMilliseconds > 1000) {
      isComplete = false;
    }
    // 播放状态变化时，更新

    Future<void> send() {
      return VideoHttp.heartBeat(
        aid: aid ?? _aid,
        bvid: bvid ?? _bvid,
        cid: cid ?? this.cid,
        progress: progress,
        epid: epid ?? _epid,
        seasonId: seasonId ?? _seasonId,
        subType: pgcType ?? _pgcType,
        videoType: videoType ?? _videoType,
      );
    }

    switch (type) {
      case HeartBeatType.playing:
        if (progress - _heartDuration >= 5) {
          _heartDuration = progress;
          return send();
        }
      case HeartBeatType.status:
        if (progress - _heartDuration >= 2) {
          _heartDuration = progress;
          return send();
        }
      case HeartBeatType.completed:
        if (isComplete) progress = -1;
        return send();
    }
    return null;
  }

  void setPlayRepeat(PlayRepeat type) {
    playRepeat = type;
    if (!Pref.tempPlayerConf) video.put(VideoBoxKey.playRepeat, type.index);
  }

  void putSubtitleSettings() {
    setting.putAllNE({
      SettingBoxKey.subtitleFontScale: subtitleFontScale,
      SettingBoxKey.subtitleFontScaleFS: subtitleFontScaleFS,
      SettingBoxKey.subtitlePaddingH: subtitlePaddingH,
      SettingBoxKey.subtitlePaddingB: subtitlePaddingB,
      SettingBoxKey.subtitleBgOpacity: subtitleBgOpacity,
      SettingBoxKey.subtitleStrokeWidth: subtitleStrokeWidth,
      SettingBoxKey.subtitleFontWeight: subtitleFontWeight,
    });
  }

  bool isCloseAll = false;
  Future<void> dispose() async {
    // 使用锁防止并发调用 dispose
    await _disposeLock.synchronized(() async {
      // 检查是否已释放，防止重复释放
      if (_isDisposed) {
        return;
      }

      // 每次减1，最后销毁
      cancelLongPressTimer();
      if (!isCloseAll && _playerCount > 1) {
        _playerCount -= 1;
        _heartDuration = 0;
        if (!_isPreviousVideoPage) {
          pause();
        }
        return;
      }

      _playerCount = 0;
      danmakuController = null;
      _stopListenerForVideoFit();
      _stopListenerForEnterFullScreen();
      _disableAutoEnterPip();
      setPlayCallBack(null);
      dmState.clear();
      if (showSeekPreview) {
        _clearPreview();
      }
      Utils.channel.setMethodCallHandler(null);
      _timer?.cancel();
      _timerForSeek?.cancel();

      // 先移除监听器，防止在关闭 Rx 变量时触发回调
      await removeListeners();

      // 关闭所有 Rx 响应式变量以释放内存
      dataStatus.close();
      positionSeconds.close();
      sliderPositionSeconds.close();
      sliderTempPosition.close();
      duration.close();
      buffered.close();
      bufferedSeconds.close();
      _playbackSpeed.close();
      _longPressSpeed.close();
      volume.close();
      brightness.close();
      showControls.close();
      showBrightnessStatus.close();
      longPressStatus.close();
      controlsLock.close();
      isFullScreen.close();
      videoFit.close();
      continuePlayInBackground.close();
      isSliderMoving.close();
      width.close();
      height.close();
      onlyPlayAudio.close();
      flipX.close();
      flipY.close();
      isBuffering.close();
      _enableShowDanmaku.close();
      _enableShowLiveDanmaku.close();
      isAlwaysOnTop.close();
      danmakuOpacity.close();
      subtitleConfig.close();
      volumeIndicator.close();
      volumeInterceptEventStream.close();
      mountSeekBackwardButton.close();
      mountSeekForwardButton.close();
      showPreview.close();

      if (PlatformUtils.isDesktop && isAlwaysOnTop.value) {
        windowManager.setAlwaysOnTop(false);
      }

      _positionListeners.clear();
      _statusListeners.clear();
      if (playerStatus.isPlaying) {
        WakelockPlus.disable();
      }

      // 先清空 textureId 让 UI 停止渲染，再释放原生播放器
      _textureIdRx.value = null;

      // 给 Flutter 一帧时间处理 texture 释放
      await Future.delayed(Duration.zero);

      _nativePlayer?.dispose();
      _nativePlayer = null;
      _textureIdRx.close();
      _instance = null;
      videoPlayerServiceHandler?.clear();

      _isDisposed = true;
    });
  }

  static void updatePlayCount() {
    if (_instance?._playerCount == 1) {
      _instance?.dispose();
    } else {
      _instance?._playerCount -= 1;
    }
  }

  void setContinuePlayInBackground() {
    continuePlayInBackground.value = !continuePlayInBackground.value;
    if (!tempPlayerConf) {
      setting.put(
        SettingBoxKey.continuePlayInBackground,
        continuePlayInBackground.value,
      );
    }
  }

  void setOnlyPlayAudio() {
    onlyPlayAudio.value = !onlyPlayAudio.value;
    _nativePlayer?.setVideoTrackEnabled(!onlyPlayAudio.value);
  }

  late final Map<String, ui.Image?> previewCache = {};
  LoadingState<VideoShotData>? videoShot;
  late final RxBool showPreview = false.obs;
  late final showSeekPreview = Pref.showSeekPreview;
  late final previewIndex = RxnInt();

  void updatePreviewIndex(int seconds) {
    if (videoShot == null) {
      videoShot = LoadingState.loading();
      getVideoShot();
      return;
    }
    if (videoShot case Success(:final response)) {
      showPreview.value = true;
      previewIndex.value = max(
        0,
        (response.index.where((item) => item <= seconds).length - 2),
      );
    }
  }

  void _clearPreview() {
    showPreview.value = false;
    previewIndex.value = null;
    videoShot = null;
    for (final i in previewCache.values) {
      i?.dispose();
    }
    previewCache.clear();
  }

  Future<void> getVideoShot() async {
    try {
      final res = await Request().get(
        '/x/player/videoshot',
        queryParameters: {
          // 'aid': IdUtils.bv2av(_bvid),
          'bvid': _bvid,
          'cid': cid,
          'index': 1,
        },
        options: Options(
          headers: {
            'user-agent': UaType.pc.ua,
            'referer': 'https://www.bilibili.com/video/$bvid',
          },
        ),
      );
      if (res.data['code'] == 0) {
        final data = VideoShotData.fromJson(res.data['data']);
        if (data.index.isNotEmpty) {
          videoShot = Success(data);
          return;
        }
      }
      videoShot = const Error(null);
    } catch (e) {
      videoShot = const Error(null);
      if (kDebugMode) debugPrint('getVideoShot: $e');
    }
  }

  void takeScreenshot() {
    SmartDialog.showToast('截图中');
    screenshot().then((value) {
      if (value != null) {
        SmartDialog.showToast('点击弹窗保存截图');
        showDialog(
          context: Get.context!,
          builder: (context) => GestureDetector(
            onTap: () {
              Get.back();
              ImageUtils.saveByteImg(
                bytes: value,
                fileName: 'screenshot_${ImageUtils.time}',
              );
            },
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: min(Get.width / 3, 350),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        width: 5,
                        color: Get.theme.colorScheme.surface,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Image.memory(value),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        SmartDialog.showToast('截图失败');
      }
    });
  }

  bool onPopInvokedWithResult(bool didPop, Object? result) {
    if (Platform.isAndroid && didPop) {
      _disableAutoEnterPipIfNeeded();
    }
    if (controlsLock.value) {
      onLockControl(false);
      return true;
    }
    if (isDesktopPip) {
      exitDesktopPip();
      return true;
    }
    if (isFullScreen.value) {
      triggerFullScreen(status: false);
      return true;
    }
    return false;
  }
}
