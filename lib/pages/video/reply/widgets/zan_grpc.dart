import 'package:PiliPro/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:PiliPro/http/reply.dart';
import 'package:PiliPro/services/haptic_service.dart';
import 'package:PiliPro/utils/num_utils.dart';
import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 点赞状态快照，用于乐观更新失败时回滚
class _LikeStateSnapshot {
  final $fixnum.Int64 like;
  final $fixnum.Int64 action;
  
  _LikeStateSnapshot(this.like, this.action);
  
  factory _LikeStateSnapshot.fromReply(ReplyInfo reply) {
    return _LikeStateSnapshot(
      reply.like,
      reply.replyControl.action,
    );
  }
}

class ZanButtonGrpc extends StatefulWidget {
  const ZanButtonGrpc({
    super.key,
    required this.replyItem,
  });

  final ReplyInfo replyItem;

  @override
  State<ZanButtonGrpc> createState() => _ZanButtonGrpcState();
}

class _ZanButtonGrpcState extends State<ZanButtonGrpc> {
  bool _isProcessing = false;
  
  /// 乐观更新状态
  bool _optimisticIsLike = false;
  bool _optimisticIsDislike = false;
  int _optimisticLikeCount = 0;
  bool _hasOptimisticUpdate = false;

  @override
  void initState() {
    super.initState();
    _syncFromReply();
  }

  @override
  void didUpdateWidget(ZanButtonGrpc oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有当没有乐观更新时才同步
    if (!_hasOptimisticUpdate) {
      _syncFromReply();
    }
  }

  void _syncFromReply() {
    final action = widget.replyItem.replyControl.action;
    _optimisticIsLike = action == $fixnum.Int64.ONE;
    _optimisticIsDislike = action == $fixnum.Int64.TWO;
    _optimisticLikeCount = widget.replyItem.like.toInt();
  }

  /// 应用乐观更新状态到 ReplyInfo
  void _applyOptimisticState() {
    widget.replyItem.replyControl.action = _optimisticIsLike
        ? $fixnum.Int64.ONE
        : _optimisticIsDislike
            ? $fixnum.Int64.TWO
            : $fixnum.Int64.ZERO;
    widget.replyItem.like = $fixnum.Int64(_optimisticLikeCount);
  }

  /// 回滚到原始状态
  void _rollbackToSnapshot(_LikeStateSnapshot snapshot) {
    setState(() {
      _optimisticIsLike = snapshot.action == $fixnum.Int64.ONE;
      _optimisticIsDislike = snapshot.action == $fixnum.Int64.TWO;
      _optimisticLikeCount = snapshot.like.toInt();
      _hasOptimisticUpdate = false;
    });
    widget.replyItem.like = snapshot.like;
    widget.replyItem.replyControl.action = snapshot.action;
  }

  Future<void> _onHateReply() async {
    if (_isProcessing) return;
    
    // 保存当前状态用于回滚
    final snapshot = _LikeStateSnapshot.fromReply(widget.replyItem);
    
    // 计算新的状态
    final willDislike = !_optimisticIsDislike;
    final wasLike = _optimisticIsLike;
    
    // 乐观更新 UI
    setState(() {
      _isProcessing = true;
      _hasOptimisticUpdate = true;
      _optimisticIsDislike = willDislike;
      if (willDislike && wasLike) {
        // 从点赞切换到点踩
        _optimisticIsLike = false;
        _optimisticLikeCount--;
      }
    });
    
    // 应用状态到数据模型
    _applyOptimisticState();
    
    // 触觉反馈
    HapticService.to.feedback(HapticType.heavyImpact);

    // 发送请求
    final res = await ReplyHttp.hateReply(
      type: widget.replyItem.type.toInt(),
      action: willDislike ? 1 : 0,
      oid: widget.replyItem.oid.toInt(),
      rpid: widget.replyItem.id.toInt(),
    );

    if (res.isSuccess) {
      // 请求成功，保持乐观更新状态
      SmartDialog.showToast(willDislike ? '点踩成功' : '取消踩');
      setState(() {
        _hasOptimisticUpdate = false;
      });
    } else {
      // 请求失败，回滚状态
      _rollbackToSnapshot(snapshot);
      res.toast();
    }
    
    setState(() {
      _isProcessing = false;
    });
  }

  Future<void> _onLikeReply() async {
    if (_isProcessing) return;
    
    // 保存当前状态用于回滚
    final snapshot = _LikeStateSnapshot.fromReply(widget.replyItem);
    
    // 计算新的状态
    final willLike = !_optimisticIsLike;
    final wasDislike = _optimisticIsDislike;
    
    // 乐观更新 UI
    setState(() {
      _isProcessing = true;
      _hasOptimisticUpdate = true;
      _optimisticIsLike = willLike;
      if (willLike) {
        _optimisticLikeCount++;
        if (wasDislike) {
          _optimisticIsDislike = false;
        }
      } else {
        _optimisticLikeCount--;
      }
    });
    
    // 应用状态到数据模型
    _applyOptimisticState();
    
    // 触觉反馈
    HapticService.to.feedback(HapticType.heavyImpact);

    // 发送请求
    final action = willLike ? 1 : 0; // 1=点赞, 0=取消
    final res = await ReplyHttp.likeReply(
      type: widget.replyItem.type.toInt(),
      oid: widget.replyItem.oid.toInt(),
      rpid: widget.replyItem.id.toInt(),
      action: action,
    );

    if (res.isSuccess) {
      // 请求成功，保持乐观更新状态
      SmartDialog.showToast(willLike ? '点赞成功' : '取消赞');
      setState(() {
        _hasOptimisticUpdate = false;
      });
    } else {
      // 请求失败，回滚状态
      _rollbackToSnapshot(snapshot);
      res.toast();
    }
    
    setState(() {
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final primary = theme.colorScheme.primary;
    final ButtonStyle style = TextButton.styleFrom(
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 32,
          child: TextButton(
            style: style,
            onPressed: _isProcessing ? null : _onHateReply,
            child: Icon(
              _optimisticIsDislike
                  ? FontAwesomeIcons.solidThumbsDown
                  : FontAwesomeIcons.thumbsDown,
              size: 16,
              color: _optimisticIsDislike ? primary : outline,
              semanticLabel: _optimisticIsDislike ? '已踩' : '点踩',
            ),
          ),
        ),
        SizedBox(
          height: 32,
          child: TextButton(
            style: style,
            onPressed: _isProcessing ? null : _onLikeReply,
            child: Row(
              spacing: 4,
              children: [
                Icon(
                  _optimisticIsLike
                      ? FontAwesomeIcons.solidThumbsUp
                      : FontAwesomeIcons.thumbsUp,
                  size: 16,
                  color: _optimisticIsLike ? primary : outline,
                  semanticLabel: _optimisticIsLike ? '已赞' : '点赞',
                ),
                Text(
                  NumUtils.numFormat(_optimisticLikeCount),
                  style: TextStyle(
                    color: _optimisticIsLike ? primary : outline,
                    fontSize: theme.textTheme.labelSmall!.fontSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}