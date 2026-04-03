/// 저장 폴더(나의 취향) 모델
/// 서버 연동 시 fromJson / toJson 을 그대로 사용합니다.
class SaveFolder {
  final String id;
  String name;
  int postCount;
  String? thumbnailUrl; // null 이면 기본 체크무늬 표시
  final DateTime? createdAt;

  SaveFolder({
    required this.id,
    required this.name,
    required this.postCount,
    this.thumbnailUrl,
    this.createdAt,
  });

  // ── 서버 → 앱 (JSON 역직렬화) ──────────────────────────
  factory SaveFolder.fromJson(Map<String, dynamic> json) {
    return SaveFolder(
      id:           json['folderId']?.toString() ?? json['id']?.toString() ?? '',
      name:         json['name'] as String? ?? '',
      postCount:    (json['postCount'] as num?)?.toInt() ?? 0,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      createdAt:    json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  // ── 앱 → 서버 (JSON 직렬화) ────────────────────────────
  Map<String, dynamic> toJson() => {
    'id':           id,
    'name':         name,
    'postCount':    postCount,
    'thumbnailUrl': thumbnailUrl,
    'createdAt':    createdAt?.toIso8601String(),
  };
}
