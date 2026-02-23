import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 播放器 UI 状态聚合类
/// 将相关的 UI 状态变量合并，减少 Obx 监听器的数量
class PlayerUiState {
  // 播放进度相关
  final RxInt positionSeconds = 0.obs;
  final RxInt sliderPositionSeconds = 0.obs;
  final Rx<Duration> sliderTempPosition = Rx(Duration.zero);
  final Rx<Duration> duration = Rx(Duration.zero);
  final RxInt bufferedSeconds = 0.obs;

  // 控制栏状态
  final RxBool showControls = false.obs;
  final RxBool isSliderMoving = false.obs;
  final RxBool controlsLock = false.obs;
  final RxBool longPressStatus = false.obs;

  // 全屏和方向
  final RxBool isFullScreen = false.obs;

  // 缓冲状态
  final RxBool isBuffering = true.obs;

  // 播放控制按钮状态
  final RxBool mountSeekBackwardButton = false.obs;
  final RxBool mountSeekForwardButton = false.obs;

  // 显示状态
  final RxBool showBrightnessStatus = false.obs;

  // 更新所有进度相关的状态（减少多次 set 带来的重建）
  void updateProgress({
    required int positionSec,
    required int sliderPositionSec,
    required Duration sliderTempPos,
    required Duration dur,
    required int bufferedSec,
  }) {
    positionSeconds.value = positionSec;
    sliderPositionSeconds.value = sliderPositionSec;
    sliderTempPosition.value = sliderTempPos;
    duration.value = dur;
    bufferedSeconds.value = bufferedSec;
  }

  // 更新控制栏显示状态
  void updateControlsVisibility({
    required bool show,
    bool? locked,
  }) {
    showControls.value = show;
    if (locked != null) {
      controlsLock.value = locked;
    }
  }

  // 更新全屏状态
  void updateFullScreen(bool fullScreen) {
    isFullScreen.value = fullScreen;
  }

  // 更新缓冲状态
  void updateBuffering(bool buffering) {
    isBuffering.value = buffering;
  }

  // 重置状态
  void reset() {
    positionSeconds.value = 0;
    sliderPositionSeconds.value = 0;
    sliderTempPosition.value = Duration.zero;
    duration.value = Duration.zero;
    bufferedSeconds.value = 0;
    showControls.value = false;
    isSliderMoving.value = false;
    longPressStatus.value = false;
    isBuffering.value = true;
    mountSeekBackwardButton.value = false;
    mountSeekForwardButton.value = false;
  }

  void dispose() {
    // GetX 会自动处理 Rx 变量的清理
  }
}

/// 播放器视频渲染状态
class PlayerRenderState {
  final Rx<BoxFit> videoFit = Rx(BoxFit.contain);
  final RxBool flipX = false.obs;
  final RxBool flipY = false.obs;
  final Rxn<int> textureId = Rxn<int>();
  final Rxn<int> videoWidth = Rxn<int>();
  final Rxn<int> videoHeight = Rxn<int>();

  void updateRenderState({
    BoxFit? fit,
    bool? flipHorizontal,
    bool? flipVertical,
    int? id,
    int? width,
    int? height,
  }) {
    if (fit != null) videoFit.value = fit;
    if (flipHorizontal != null) flipX.value = flipHorizontal;
    if (flipVertical != null) flipY.value = flipVertical;
    if (id != null) textureId.value = id;
    if (width != null) videoWidth.value = width;
    if (height != null) videoHeight.value = height;
  }

  void reset() {
    videoFit.value = BoxFit.contain;
    flipX.value = false;
    flipY.value = false;
    textureId.value = null;
    videoWidth.value = null;
    videoHeight.value = null;
  }
}

/// 播放器控制按钮状态（用于底部控制栏）
class PlayerControlButtonState {
  final RxBool showDmChart = false.obs;
  final RxBool showViewPoints = false.obs;
  final RxBool showSubtitle = false.obs;
  final RxBool showSpeed = false.obs;
  final RxBool showQuality = false.obs;
  final RxBool showFit = false.obs;
  final RxBool showAiTranslate = false.obs;

  void reset() {
    showDmChart.value = false;
    showViewPoints.value = false;
    showSubtitle.value = false;
    showSpeed.value = false;
    showQuality.value = false;
    showFit.value = false;
    showAiTranslate.value = false;
  }
}
