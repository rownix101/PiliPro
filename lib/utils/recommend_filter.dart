import 'dart:math' show pow, max;

import 'package:PiliPro/models_new/model_rec_video_item.dart';
import 'package:PiliPro/models_new/model_video.dart';
import 'package:PiliPro/utils/storage_pref.dart';

/// 创作者类型分类
enum CreatorType {
  newCreator, // 新人UP：粉丝 < 1000
  smallCreator, // 小UP：1000 <= 粉丝 < 10000
  midCreator, // 中等UP：10000 <= 粉丝 < 100000
  bigCreator, // 大UP：粉丝 >= 100000
}

/// 视频质量评分结果
class VideoQualityScore {
  final double engagementScore; // 互动质量分 (0-1)
  final double depthScore; // 深度内容分 (0-1)
  final double freshnessScore; // 时效性分 (0-1)
  final double durationScore; // 时长权重分 (0.1-1.3)
  final double creatorBoost; // 创作者加成
  final double diversityBoost; // 多样性加成
  final double qualityPenalty; // 质量惩罚 (0-1)
  final bool isLowQuality; // 是否低质
  final bool isClickbait; // 是否标题党

  VideoQualityScore({
    required this.engagementScore,
    required this.depthScore,
    required this.freshnessScore,
    required this.durationScore,
    required this.creatorBoost,
    this.diversityBoost = 1.0,
    this.qualityPenalty = 0.0,
    this.isLowQuality = false,
    this.isClickbait = false,
  });

  /// 综合质量分 (0-1+，可超过1表示优质内容)
  double get totalScore {
    if (!Pref.enableQualityScoring) return 0.5;
    if (isLowQuality) return 0.1;

    final baseScore =
        engagementScore * Pref.engagementWeight +
        depthScore * Pref.depthWeight +
        freshnessScore * Pref.freshnessWeight;

    final penalizedScore = baseScore * (1 - qualityPenalty) * durationScore;
    return penalizedScore * creatorBoost * diversityBoost;
  }

  bool get isHighQuality => !isLowQuality && totalScore > 0.7;

  bool get isExplorationWorthy {
    return !isLowQuality &&
        creatorBoost > 1.0 &&
        (engagementScore > 0.5 || depthScore > 0.5);
  }
}

class RecommendationContext {
  final Set<String> recentVideoKeys;
  final Set<int> recentOwnerIds;
  final Set<String> recentTitleFingerprints;
  final Set<String> skippedVideoKeys;
  final Set<int> skippedOwnerIds;
  final Set<String> skippedTitleFingerprints;

  const RecommendationContext({
    this.recentVideoKeys = const <String>{},
    this.recentOwnerIds = const <int>{},
    this.recentTitleFingerprints = const <String>{},
    this.skippedVideoKeys = const <String>{},
    this.skippedOwnerIds = const <int>{},
    this.skippedTitleFingerprints = const <String>{},
  });

  bool get isEmpty =>
      recentVideoKeys.isEmpty &&
      recentOwnerIds.isEmpty &&
      recentTitleFingerprints.isEmpty &&
      skippedVideoKeys.isEmpty &&
      skippedOwnerIds.isEmpty &&
      skippedTitleFingerprints.isEmpty;
}

abstract final class RecommendFilter {
  // ========== 基础过滤阈值 ==========
  static int minDurationForRcmd = Pref.minDurationForRcmd;
  static int minPlayForRcmd = Pref.minPlayForRcmd;
  static int minLikeRatioForRecommend = Pref.minLikeRatioForRecommend;
  static bool exemptFilterForFollowed = Pref.exemptFilterForFollowed;
  static bool applyFilterToRelatedVideos = Pref.applyFilterToRelatedVideos;
  static RegExp rcmdRegExp = RegExp(
    Pref.banWordForRecommend,
    caseSensitive: false,
  );
  static bool enableFilter = rcmdRegExp.pattern.isNotEmpty;

  // ========== 新人UP扶持阈值 ==========
  static bool get enableNewCreatorBoost => Pref.enableNewCreatorBoost;
  static int get newCreatorMaxFollowers => Pref.newCreatorMaxFollowers;
  static int get newCreatorMinDuration => Pref.newCreatorMinDuration;
  static int get newCreatorMinPlay => Pref.newCreatorMinPlay;
  static int get newCreatorMinLikeRatio => Pref.newCreatorMinLikeRatio;

  // ========== 负向过滤关键词 ==========
  static final List<String> _clickbaitKeywords = [
    '震惊',
    '惊天',
    '重磅',
    '紧急',
    '必看',
    '不看后悔',
    '全网',
    '最',
    '第一',
    '小学生',
    '一口气看完',
    '全程高能',
    '泪目',
    '破防了',
    '绝了',
    '杀疯了',
  ];

  // ========== 检测方法 ==========

  static bool _isClickbait(String title) {
    return _clickbaitKeywords.any((kw) => title.contains(kw));
  }

  static bool _hasSuspiciousEngagement(BaseVideoItemModel videoItem) {
    final stat = videoItem.stat;
    if (stat.view == null || stat.view! < 100) return false;
    final favRate = (stat.favorite ?? 0) / stat.view!;
    final replyRate = (stat.reply ?? 0) / stat.view!;
    return favRate > 0.20 && replyRate < 0.001;
  }

  static bool _isLowQuality(BaseVideoItemModel videoItem) {
    if (!Pref.enableNegativeFilter) return false;

    if (Pref.filterSuspiciousEngagement &&
        _hasSuspiciousEngagement(videoItem)) {
      return true;
    }

    if (Pref.filterShortViral &&
        videoItem.duration > 0 &&
        videoItem.duration < 30 &&
        (videoItem.stat.view ?? 0) > 100000) {
      return true;
    }

    if (videoItem.duration > 600 && (videoItem.stat.danmu ?? 0) < 5) {
      return true;
    }

    return false;
  }

  // ========== 核心过滤方法 ==========

  static bool filter(BaseVideoItemModel videoItem) {
    if (videoItem.isFollowed && exemptFilterForFollowed) return false;
    return filterAll(videoItem);
  }

  static bool filterLikeRatio(int? like, int? view) {
    if (view != null) {
      return (view > -1 && view < minPlayForRcmd) ||
          (like != null &&
              like > -1 &&
              like * 100 < minLikeRatioForRecommend * view);
    }
    return false;
  }

  static bool filterTitle(String title) {
    return enableFilter && rcmdRegExp.hasMatch(title);
  }

  static bool filterAll(BaseVideoItemModel videoItem) {
    return (videoItem.duration > 0 &&
            videoItem.duration < minDurationForRcmd) ||
        filterLikeRatio(videoItem.stat.like, videoItem.stat.view) ||
        filterTitle(videoItem.title);
  }

  // ========== 新人UP识别 ==========

  static bool isNewCreator(BaseVideoItemModel videoItem) {
    final followers = videoItem.owner.followers;
    if (followers == null) return false;
    return followers > 0 && followers < newCreatorMaxFollowers;
  }

  static CreatorType getCreatorType(BaseVideoItemModel videoItem) {
    final followers = videoItem.owner.followers;
    if (followers == null) return CreatorType.midCreator;
    if (followers < 1000) return CreatorType.newCreator;
    if (followers < 10000) return CreatorType.smallCreator;
    if (followers < 100000) return CreatorType.midCreator;
    return CreatorType.bigCreator;
  }

  static bool filterForNewCreator(BaseVideoItemModel videoItem) {
    if (!enableNewCreatorBoost) return filterAll(videoItem);

    final durationOk =
        videoItem.duration <= 0 || videoItem.duration >= newCreatorMinDuration;
    final playOk =
        videoItem.stat.view == null ||
        videoItem.stat.view! >= newCreatorMinPlay;
    final ratioOk =
        videoItem.stat.like == null ||
        videoItem.stat.view == null ||
        videoItem.stat.view! <= 0 ||
        videoItem.stat.like! * 100 >=
            newCreatorMinLikeRatio * videoItem.stat.view!;

    return !(durationOk && playOk && ratioOk) || filterTitle(videoItem.title);
  }

  static bool smartFilter(BaseVideoItemModel videoItem) {
    if (videoItem.isFollowed && exemptFilterForFollowed) return false;
    if (_isLowQuality(videoItem)) return true;
    if (isNewCreator(videoItem)) return filterForNewCreator(videoItem);
    return filterAll(videoItem);
  }

  // ========== 质量评分系统 ==========

  static VideoQualityScore calculateQualityScore(BaseVideoItemModel videoItem) {
    return VideoQualityScore(
      engagementScore: _calculateEngagementScore(videoItem),
      depthScore: _calculateDepthScore(videoItem),
      freshnessScore: _calculateFreshnessScore(videoItem),
      durationScore: _calculateDurationScore(videoItem),
      creatorBoost: _calculateCreatorBoost(videoItem),
      qualityPenalty: _calculateQualityPenalty(videoItem),
      isLowQuality: _isLowQuality(videoItem),
      isClickbait: _isClickbait(videoItem.title),
    );
  }

  /// 时长权重分 (0.1-1.3)
  /// - 2分钟以内：强惩罚 0.1-0.4（不可豁免，越短惩罚越大）
  /// - 2-3分钟：过渡 0.4-0.5
  /// - 3-8分钟：适中 0.5-1.0（新人UP可豁免到1.0）
  /// - 8分钟以上：加权 1.0-1.3
  static double _calculateDurationScore(BaseVideoItemModel videoItem) {
    if (!Pref.enableDurationWeight) return 1.0;

    final duration = videoItem.duration;
    if (duration <= 0) return 1.0;

    const ultraShortThreshold = 120; // 2分钟
    if (duration < ultraShortThreshold) {
      // 2分钟内：非线性强惩罚（不可豁免）
      final ratio = duration / ultraShortThreshold;
      return 0.1 + ratio * ratio * 0.3;
    }

    const shortThreshold = 180; // 3分钟
    if (duration < shortThreshold) {
      // 2-3分钟：过渡区 0.4-0.5
      final progress =
          (duration - ultraShortThreshold) /
          (shortThreshold - ultraShortThreshold);
      return 0.4 + progress * 0.1;
    }

    // 3分钟以上：新人UP可豁免
    if (Pref.exemptNewCreatorFromDuration && isNewCreator(videoItem)) {
      return 1.0;
    }

    final longThreshold = Pref.longVideoThreshold;
    if (duration <= longThreshold) {
      final progress =
          (duration - shortThreshold) / (longThreshold - shortThreshold);
      return 0.5 + progress * 0.5;
    } else {
      const maxBonusDuration = 1800;
      final effectiveDuration = duration.clamp(longThreshold, maxBonusDuration);
      final bonus =
          (effectiveDuration - longThreshold) /
          (maxBonusDuration - longThreshold) *
          0.3;
      return 1.0 + bonus;
    }
  }

  static double _calculateEngagementScore(BaseVideoItemModel videoItem) {
    final stat = videoItem.stat;
    if (stat.view == null || stat.view! <= 0) return 0.5;

    final followers = videoItem.owner.followers ?? 10000;
    final effectiveViews =
        stat.view! * (1 + pow(10000 / max(followers, 100), 0.3));

    final engagement =
        (stat.like ?? 0) * 1.0 +
        (stat.coin ?? 0) * 3.0 +
        (stat.favorite ?? 0) * 5.0 +
        (stat.share ?? 0) * 4.0;

    final ratio = engagement / effectiveViews;
    return (ratio / 0.05).clamp(0.0, 1.0);
  }

  static double _calculateDepthScore(BaseVideoItemModel videoItem) {
    final stat = videoItem.stat;
    if (stat.view == null || stat.view! <= 0) return 0.5;

    final duration = videoItem.duration > 0 ? videoItem.duration / 60 : 5;
    final danmuDensity = (stat.danmu ?? 0) / duration;
    final replyRate = (stat.reply ?? 0) / stat.view!;

    final danmuScore = danmuDensity < 1
        ? danmuDensity * 0.5
        : danmuDensity > 20
        ? 1.0 - (danmuDensity - 20) * 0.02
        : 0.5 + (danmuDensity - 1) * 0.025;

    final replyScore = replyRate < 0.001
        ? replyRate * 500
        : replyRate > 0.05
        ? 1.0 - (replyRate - 0.05) * 10
        : 0.5 + (replyRate - 0.001) * 10;

    return ((danmuScore + replyScore) / 2).clamp(0.0, 1.0);
  }

  static double _calculateFreshnessScore(BaseVideoItemModel videoItem) {
    final pubdate = videoItem.pubdate;
    if (pubdate == null) return 0.5;

    final hoursOld =
        (DateTime.now().millisecondsSinceEpoch / 1000 - pubdate) / 3600;

    if (hoursOld < 1) return 1.0;
    if (hoursOld < 6) return 0.9;
    if (hoursOld < 24) return 0.8;
    if (hoursOld < 72) return 0.7;
    if (hoursOld < 168) return 0.6;
    if (hoursOld < 720) return 0.5;
    return 0.4;
  }

  static double _calculateCreatorBoost(BaseVideoItemModel videoItem) {
    if (!enableNewCreatorBoost) return 1.0;

    final type = getCreatorType(videoItem);
    switch (type) {
      case CreatorType.newCreator:
        return 1.5;
      case CreatorType.smallCreator:
        return 1.2;
      case CreatorType.midCreator:
        return 1.0;
      case CreatorType.bigCreator:
        return 0.9;
    }
  }

  static double _calculateQualityPenalty(BaseVideoItemModel videoItem) {
    double penalty = 0.0;

    if (_isClickbait(videoItem.title)) {
      penalty += Pref.clickbaitPenalty / 100;
    }

    if (_hasSuspiciousEngagement(videoItem)) {
      penalty += 0.5;
    }

    if (videoItem.duration > 0 &&
        videoItem.duration < 30 &&
        (videoItem.stat.view ?? 0) > 100000) {
      penalty += 0.4;
    }

    return penalty.clamp(0.0, 1.0);
  }

  // ========== 推荐重排序 ==========

  static List<T> reorderRecommendations<T extends BaseVideoItemModel>(
    List<T> videos, {
    bool shuffleExploration = true,
    RecommendationContext context = const RecommendationContext(),
  }) {
    if (videos.isEmpty) return videos;

    final deduplicatedVideos = _deduplicateVideos(videos);
    if (deduplicatedVideos.isEmpty) {
      return deduplicatedVideos;
    }

    final scoredVideos = deduplicatedVideos.map((v) {
      final qualityScore = calculateQualityScore(v);
      return _ScoredVideo(
        video: v,
        score: qualityScore,
        sortScore: _adjustedSortScore(v, qualityScore, context),
      );
    }).toList();

    final highQuality = scoredVideos
        .where((s) => s.score.isHighQuality)
        .toList();
    final exploration = scoredVideos
        .where((s) => s.score.isExplorationWorthy && !s.score.isHighQuality)
        .toList();
    final normal = scoredVideos
        .where((s) => !s.score.isHighQuality && !s.score.isExplorationWorthy)
        .toList();

    highQuality.sort(
      (a, b) => b.sortScore.compareTo(a.sortScore),
    );
    exploration.sort(
      (a, b) => b.sortScore.compareTo(a.sortScore),
    );
    normal.sort((a, b) => b.sortScore.compareTo(a.sortScore));

    final result = <T>[];
    final highQualitySlots = (deduplicatedVideos.length * 0.2).ceil();
    result.addAll(highQuality.take(highQualitySlots).map((s) => s.video));

    if (Pref.enableExplorationMode && exploration.isNotEmpty) {
      final explorationCount =
          (deduplicatedVideos.length * Pref.explorationRatio).round();
      final explorationSample = exploration.take(explorationCount).toList();
      if (shuffleExploration) explorationSample.shuffle();

      int explorationIndex = 0;
      int targetLength = deduplicatedVideos.length;

      while (result.length < targetLength) {
        if (explorationIndex < explorationSample.length &&
            result.length % 3 == 0) {
          result.add(explorationSample[explorationIndex++].video);
        } else if (normal.isNotEmpty) {
          result.add(normal.removeAt(0).video);
        } else if (explorationIndex < explorationSample.length) {
          result.add(explorationSample[explorationIndex++].video);
        } else {
          break;
        }
      }
    } else {
      result.addAll(normal.map((s) => s.video));
    }

    result
      ..addAll(highQuality.skip(highQualitySlots).map((s) => s.video))
      ..addAll(exploration.map((s) => s.video));

    final diversified = Pref.enableDiversityQuota
        ? _applyDiversitySpacing(result, context)
        : result;
    final conservative = _applyConservativeReorder(
      deduplicatedVideos,
      diversified,
    );

    if (conservative.length > deduplicatedVideos.length) {
      return conservative.sublist(0, deduplicatedVideos.length);
    }
    return conservative;
  }

  static RecommendationContext currentContext() {
    return RecommendationContext(
      recentVideoKeys: Pref.recentRecommendationVideoKeys.toSet(),
      recentOwnerIds: Pref.recentRecommendationOwnerIds.toSet(),
      recentTitleFingerprints: Pref.recentRecommendationTitleFingerprints
          .toSet(),
      skippedVideoKeys: Pref.skippedRecommendationVideoKeys.toSet(),
      skippedOwnerIds: Pref.skippedRecommendationOwnerIds.toSet(),
      skippedTitleFingerprints: Pref.skippedRecommendationTitleFingerprints
          .toSet(),
    );
  }

  static List<T> deduplicateRecommendations<T extends BaseVideoItemModel>(
    List<T> videos,
  ) {
    return _deduplicateVideos(videos);
  }

  static double _adjustedSortScore(
    BaseVideoItemModel videoItem,
    VideoQualityScore qualityScore,
    RecommendationContext context,
  ) {
    var adjusted = qualityScore.totalScore;
    if (context.isEmpty) {
      return adjusted;
    }

    final videoKey = Pref.recommendationVideoKey(videoItem);
    final titleFingerprint = Pref.recommendationTitleFingerprint(
      videoItem.title,
    );
    final ownerId = videoItem.owner.mid;

    if (videoKey.isNotEmpty && context.recentVideoKeys.contains(videoKey)) {
      adjusted *= 0.45;
    }
    if (videoKey.isNotEmpty && context.skippedVideoKeys.contains(videoKey)) {
      adjusted *= 0.2;
    }
    if (ownerId != null && context.recentOwnerIds.contains(ownerId)) {
      adjusted *= 0.82;
    }
    if (ownerId != null && context.skippedOwnerIds.contains(ownerId)) {
      adjusted *= 0.68;
    }
    if (titleFingerprint.isNotEmpty &&
        context.recentTitleFingerprints.contains(titleFingerprint)) {
      adjusted *= 0.88;
    }
    if (titleFingerprint.isNotEmpty &&
        context.skippedTitleFingerprints.contains(titleFingerprint)) {
      adjusted *= 0.72;
    }
    return adjusted.clamp(0.01, 3.0);
  }

  static List<T> _deduplicateVideos<T extends BaseVideoItemModel>(
    List<T> videos,
  ) {
    final seenKeys = <String>{};
    final result = <T>[];
    for (final video in videos) {
      final key = Pref.recommendationVideoKey(video);
      if (key.isEmpty || seenKeys.add(key)) {
        result.add(video);
      }
    }
    return result;
  }

  static List<T> _applyDiversitySpacing<T extends BaseVideoItemModel>(
    List<T> videos,
    RecommendationContext context,
  ) {
    final remaining = List<T>.from(videos);
    final result = <T>[];
    while (remaining.isNotEmpty) {
      final searchWindow = remaining.length < 6 ? remaining.length : 6;
      int chosenIndex = 0;
      for (var i = 0; i < searchWindow; i++) {
        final candidate = remaining[i];
        final similarToRecent =
            result.isNotEmpty &&
            _isSimilarRecommendation(candidate, result.last);
        final similarToHistory =
            result.length > 1 &&
            _isSimilarRecommendation(candidate, result[result.length - 2]);
        final conflictsWithSkipped = _conflictsWithSkipped(candidate, context);
        if (!similarToRecent && !similarToHistory && !conflictsWithSkipped) {
          chosenIndex = i;
          break;
        }
      }
      result.add(remaining.removeAt(chosenIndex));
    }
    return result;
  }

  static bool _conflictsWithSkipped(
    BaseVideoItemModel candidate,
    RecommendationContext context,
  ) {
    final ownerId = candidate.owner.mid;
    final fingerprint = Pref.recommendationTitleFingerprint(candidate.title);
    return (ownerId != null && context.skippedOwnerIds.contains(ownerId)) ||
        (fingerprint.isNotEmpty &&
            context.skippedTitleFingerprints.contains(fingerprint));
  }

  static bool _isSimilarRecommendation(
    BaseVideoItemModel current,
    BaseVideoItemModel previous,
  ) {
    final currentOwnerId = current.owner.mid;
    final previousOwnerId = previous.owner.mid;
    if (currentOwnerId != null && currentOwnerId == previousOwnerId) {
      return true;
    }
    final currentGoto = current is BaseRecVideoItemModel
        ? current.goto
        : current.runtimeType;
    final previousGoto = previous is BaseRecVideoItemModel
        ? previous.goto
        : previous.runtimeType;
    if (currentGoto == previousGoto) {
      final currentFingerprint = Pref.recommendationTitleFingerprint(
        current.title,
      );
      final previousFingerprint = Pref.recommendationTitleFingerprint(
        previous.title,
      );
      if (currentFingerprint.isNotEmpty &&
          currentFingerprint == previousFingerprint) {
        return true;
      }
    }
    return _durationBucket(current.duration) ==
        _durationBucket(previous.duration);
  }

  static int _durationBucket(int duration) {
    if (duration <= 0) return 0;
    if (duration < 180) return 1;
    if (duration < 600) return 2;
    if (duration < 1200) return 3;
    return 4;
  }

  static List<T> _applyConservativeReorder<T extends BaseVideoItemModel>(
    List<T> original,
    List<T> reranked,
  ) {
    if (original.length < 4 || original.length != reranked.length) {
      return reranked;
    }
    final originalIndex = <String, int>{};
    for (var i = 0; i < original.length; i++) {
      originalIndex.putIfAbsent(
        Pref.recommendationVideoKey(original[i]),
        () => i,
      );
    }

    final remaining = List<T>.from(reranked);
    final result = <T>[];
    const maxShift = 4;
    while (remaining.isNotEmpty) {
      final targetIndex = result.length;
      final searchWindow = remaining.length < 6 ? remaining.length : 6;
      int chosenIndex = 0;
      for (var i = 0; i < searchWindow; i++) {
        final key = Pref.recommendationVideoKey(remaining[i]);
        final index = originalIndex[key] ?? targetIndex;
        if ((index - targetIndex).abs() <= maxShift) {
          chosenIndex = i;
          break;
        }
      }
      result.add(remaining.removeAt(chosenIndex));
    }
    return result;
  }
}

class _ScoredVideo<T extends BaseVideoItemModel> {
  final T video;
  final VideoQualityScore score;
  final double sortScore;
  _ScoredVideo({
    required this.video,
    required this.score,
    required this.sortScore,
  });
}
