import 'package:flutter_naver_map/flutter_naver_map.dart';

enum BlockType {
  hazard,
  cultural,
  restaurant,
  cafe,
  tip,
  other,
}

class MapBlock {
  final String id;
  final NLatLng center;
  final double radius;
  final BlockType type;
  final String comment;
  final DateTime createdAt;
  
  // 투표 및 상태 관리 (새롭게 추가)
  int keepVotes;      // 유지 투표수
  int removeVotes;    // 삭제 투표수
  bool isPermanent;   // 영구 유지 확정 여부

  MapBlock({
    required this.id,
    required this.center,
    required this.radius,
    required this.type,
    required this.comment,
    required this.createdAt,
    this.keepVotes = 0,
    this.removeVotes = 0,
    this.isPermanent = false,
  });

  // 투표 집계 정보
  int get totalVotes => keepVotes + removeVotes;
  bool get hasVotes => totalVotes > 0;
  
  // 과반수 투표 여부 (50% 초과)
  bool get isKeepMajority => hasVotes && (keepVotes / totalVotes) > 0.5;
  bool get isRemoveMajority => hasVotes && (removeVotes / totalVotes) > 0.5;

  // 만료 여부 판단
  // 1. 이미 영구 확정된 경우 만료되지 않음 (단, 삭제 투표 과반수면 만료/삭제됨)
  // 2. 핀 유형(맛집 등)은 항상 영구적
  // 3. 24시간이 경과한 경우 만료
  bool get isExpired {
    if (isRemoveMajority) return true; // 삭제 과반수면 즉시 만료(삭제)
    if (isPin || isPermanent) return false;
    return DateTime.now().difference(createdAt).inHours >= 24;
  }

  // 마커 기반 핀(포인트) 여부
  bool get isPin => type != BlockType.hazard && type != BlockType.cultural;

  // 잔여 시간 계산 (24시간 기준)
  Duration get remainingTime {
    if (isPin || isPermanent) return Duration.zero;
    final elapsed = DateTime.now().difference(createdAt);
    final remaining = const Duration(hours: 24) - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // 잔여 시간 문자열 (HH:mm:ss)
  String get remainingTimeString {
    if (isPin || isPermanent) return isPermanent ? '영구 유지' : '영구 보관';
    final rem = remainingTime;
    if (rem == Duration.zero) return '만료 임박';
    
    final hours = rem.inHours.toString().padLeft(2, '0');
    final minutes = (rem.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (rem.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds 남음';
  }

  /// 서버 전송용 JSON 직렬화
  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': center.latitude,
    'longitude': center.longitude,
    'radius': radius,
    'type': type.name,
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
    'keepVotes': keepVotes,
    'removeVotes': removeVotes,
    'isPermanent': isPermanent,
  };

  /// 서버 응답 JSON 역직렬화
  factory MapBlock.fromJson(Map<String, dynamic> json) => MapBlock(
    id: json['id'].toString(),
    center: NLatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    ),
    radius: (json['radius'] as num).toDouble(),
    type: BlockType.values.firstWhere(
      (e) => e.name == json['type'] || e.toString().split('.').last == json['type'],
      orElse: () => BlockType.hazard,
    ),
    comment: json['comment'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    keepVotes: json['keepVotes'] ?? 0,
    removeVotes: json['removeVotes'] ?? 0,
    isPermanent: json['isPermanent'] ?? false,
  );
}

