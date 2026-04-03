/// 📁 폴더 모델 (4-2. 내 폴더 목록 조회 Response)
class Folder {
  final int folderId;
  final String name;
  final DateTime createdAt;

  Folder({
    required this.folderId,
    required this.name,
    required this.createdAt,
  });

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      folderId: json['folderId'] as int,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'folderId': folderId,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// 📝 폴더 내 게시물 모델 (4-4. 폴더 내 게시물 목록 조회 Response)
class FolderQuestion {
  final int questionId;
  final String title;
  final String category;
  final String authorNickname;
  final int answerCount;
  final int likeCount;
  final DateTime createdAt;
  final String? thumbnailUrl;
  final double latitude;
  final double longitude;

  FolderQuestion({
    required this.questionId,
    required this.title,
    required this.category,
    required this.authorNickname,
    required this.answerCount,
    required this.likeCount,
    required this.createdAt,
    this.thumbnailUrl,
    required this.latitude,
    required this.longitude,
  });

  factory FolderQuestion.fromJson(Map<String, dynamic> json) {
    return FolderQuestion(
      questionId: json['questionId'] as int,
      title: json['title'] as String,
      category: json['category'] as String,
      authorNickname: json['authorNickname'] as String,
      answerCount: json['answerCount'] as int,
      likeCount: json['likeCount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

/// 📍 폴더 내 핀 모델 (4-5. 폴더 내 화면 영역 핀 목록 조회 Response)
class FolderPin {
  final int questionId;
  final double latitude;
  final double longitude;
  final String category;
  final String title;
  final String? thumbnailUrl;

  FolderPin({
    required this.questionId,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.title,
    this.thumbnailUrl,
  });

  factory FolderPin.fromJson(Map<String, dynamic> json) {
    return FolderPin(
      questionId: json['questionId'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      category: json['category'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }
}
