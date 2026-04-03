abstract class BaseSimpleVideoItemModel {
  late String title;
  String? bvid;
  int? cid;
  String? cover;
  int duration = -1;
  late BaseOwner owner;
  late BaseStat stat;
}

abstract class BaseVideoItemModel extends BaseSimpleVideoItemModel {
  int? aid;
  String? desc;
  int? pubdate;
  bool isFollowed = false;
}

abstract class BaseOwner {
  int? mid;
  String? name;
  int? followers; // 粉丝数，用于新人UP识别
}

abstract class BaseStat {
  int? view;
  int? like;
  int? danmu;
  int? coin; // 投币数
  int? favorite; // 收藏数
  int? reply; // 评论数
  int? share; // 分享数
}

class Stat extends BaseStat {
  Stat.fromJson(Map<String, dynamic> json) {
    view = json["view"];
    like = json["like"];
    danmu = json['danmaku'];
    coin = json['coin'];
    favorite = json['favorite'];
    reply = json['reply'];
    share = json['share'];
  }
}

class PlayStat extends BaseStat {
  PlayStat.fromJson(Map<String, dynamic> json) {
    view = json['play'];
    danmu = json['danmaku'];
    like = json['like'];
    coin = json['coin'];
    favorite = json['favorite'];
    reply = json['reply'];
    share = json['share'];
  }
}
