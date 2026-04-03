import 'package:PiliPro/models_new/model_video.dart';
import 'package:PiliPro/utils/utils.dart';
import 'package:hive/hive.dart';

part 'model_owner.g.dart';

@HiveType(typeId: 3)
class Owner implements BaseOwner {
  Owner({
    this.mid,
    this.name,
    this.face,
    this.followers,
  });
  @HiveField(0)
  @override
  int? mid;
  @HiveField(1)
  @override
  String? name;
  @HiveField(2)
  String? face;
  @HiveField(3)
  @override
  int? followers;

  Owner.fromJson(Map<String, dynamic> json) {
    mid = Utils.safeToInt(json["mid"]);
    name = json["name"];
    face = json['face'];
    followers = Utils.safeToInt(json['fans'] ?? json['follower'] ?? 0);
  }

  Map<String, dynamic> toJson() => {
    'mid': mid,
    'name': name,
    'face': face,
  };
}
