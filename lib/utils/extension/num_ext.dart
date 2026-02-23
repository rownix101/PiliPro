import 'dart:math' show pow;

import 'package:flutter/widgets.dart';

/// 图片尺寸缓存管理器
/// 用于缓存设备像素比，避免频繁调用 MediaQuery
class _CacheSizeManager {
  static final _CacheSizeManager _instance = _CacheSizeManager._internal();
  factory _CacheSizeManager() => _instance;
  _CacheSizeManager._internal();

  double? _cachedDevicePixelRatio;

  /// 获取缓存的设备像素比
  double getDevicePixelRatio(BuildContext context) {
    // 如果缓存的值与当前值不同，更新缓存
    final currentRatio = MediaQuery.devicePixelRatioOf(context);
    if (_cachedDevicePixelRatio != currentRatio) {
      _cachedDevicePixelRatio = currentRatio;
    }
    return _cachedDevicePixelRatio ?? currentRatio;
  }

  /// 计算并缓存尺寸
  int? calculateSize(num value, BuildContext context) {
    if (value == 0) return null;

    final ratio = getDevicePixelRatio(context);
    final size = (value * ratio).round();

    return size;
  }
}

/// 全局缓存管理器实例
final _cacheSizeManager = _CacheSizeManager();

extension ImageExtension on num {
  /// 计算图片缓存尺寸
  /// 对于频繁调用的场景，会使用内部缓存优化性能
  int? cacheSize(BuildContext context) {
    if (this == 0) {
      return null;
    }
    return _cacheSizeManager.calculateSize(this, context);
  }

  /// 快速计算缓存尺寸，不经过缓存管理器
  /// 适用于单次计算或性能不敏感的场景
  int? cacheSizeFast(BuildContext context) {
    if (this == 0) {
      return null;
    }
    return (this * MediaQuery.devicePixelRatioOf(context)).round();
  }
}

extension IntExt on int? {
  int? operator +(int other) => this == null ? null : this! + other;
  int? operator -(int other) => this == null ? null : this! - other;
}

extension DoubleExt on double {
  double toPrecision(int fractionDigits) {
    final mod = pow(10, fractionDigits).toDouble();
    return (this * mod).roundToDouble() / mod;
  }
}
