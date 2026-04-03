/// 📍 3-2. 지도 핀 모델 (화면 영역 내 핀 목록 조회 응답)
class MapPin {
  final int pinId;
  final double latitude;
  final double longitude;
  final String pinType; // DANGER | RESTAURANT | CAUTION
  final String title;

  MapPin({
    required this.pinId,
    required this.latitude,
    required this.longitude,
    required this.pinType,
    required this.title,
  });

  factory MapPin.fromJson(Map<String, dynamic> json) {
    return MapPin(
      pinId: json['pinId'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      pinType: json['pinType'] as String,
      title: json['title'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'pinId': pinId,
        'latitude': latitude,
        'longitude': longitude,
        'pinType': pinType,
        'title': title,
      };
}
