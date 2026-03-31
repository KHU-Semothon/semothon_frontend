import 'package:flutter_naver_map/flutter_naver_map.dart';

enum BlockType {
  hazard,
  cultural,
}

class MapBlock {
  final String id;
  final NLatLng center;
  final double radius;
  final BlockType type;
  final String comment;
  final DateTime createdAt;

  MapBlock({
    required this.id,
    required this.center,
    required this.radius,
    required this.type,
    required this.comment,
    required this.createdAt,
  });

  // 24시간이 지났는지 여부를 판단하는 getter
  bool get isExpired => DateTime.now().difference(createdAt).inHours >= 24;
}
