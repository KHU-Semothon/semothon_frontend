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

  /// 서버 전송용 JSON 직렬화
  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': center.latitude,
    'longitude': center.longitude,
    'radius': radius,
    'type': type.name,           // 'hazard' | 'cultural'
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
  };

  /// 서버 응답 JSON 역직렬화
  factory MapBlock.fromJson(Map<String, dynamic> json) => MapBlock(
    id: json['id'].toString(),
    center: NLatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    ),
    radius: (json['radius'] as num).toDouble(),
    type: json['type'] == 'cultural' ? BlockType.cultural : BlockType.hazard,
    comment: json['comment'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

