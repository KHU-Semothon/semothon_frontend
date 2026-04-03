/// 📝 2-2. 질문 목록 아이템 (getQuestions 응답의 content 항목)
class QuestionListItem {
  final int questionId;
  final String title;
  final String category;
  final String authorNickname;
  final DateTime createdAt;
  final int answerCount;
  final int likeCount;
  final double latitude;
  final double longitude;
  final String? thumbnailUrl;

  QuestionListItem({
    required this.questionId,
    required this.title,
    required this.category,
    required this.authorNickname,
    required this.createdAt,
    required this.answerCount,
    required this.likeCount,
    required this.latitude,
    required this.longitude,
    this.thumbnailUrl,
  });

  factory QuestionListItem.fromJson(Map<String, dynamic> json) {
    return QuestionListItem(
      questionId: json['questionId'] as int,
      title: json['title'] as String,
      category: json['category'] as String,
      authorNickname: json['authorNickname'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      answerCount: json['answerCount'] as int,
      likeCount: json['likeCount'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }
}

/// 📝 2-2. 질문 목록 페이지 응답 (페이지네이션 포함)
class QuestionPage {
  final List<QuestionListItem> content;
  final int totalPages;
  final int totalElements;
  final bool isLast;

  QuestionPage({
    required this.content,
    required this.totalPages,
    required this.totalElements,
    required this.isLast,
  });

  factory QuestionPage.fromJson(Map<String, dynamic> json) {
    final List<dynamic> contentList = json['content'] ?? [];
    return QuestionPage(
      content: contentList
          .map((item) => QuestionListItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalPages: json['totalPages'] as int,
      totalElements: json['totalElements'] as int,
      isLast: json['isLast'] as bool,
    );
  }
}

/// 💬 2-3. 답변 모델
class Answer {
  final int answerId;
  final String content;
  final String authorNickname;
  final int authorTrustScore;
  final String authorExperience;
  final bool isAccepted;
  final DateTime createdAt;
  final List<String> mediaUrls;

  Answer({
    required this.answerId,
    required this.content,
    required this.authorNickname,
    required this.authorTrustScore,
    required this.authorExperience,
    required this.isAccepted,
    required this.createdAt,
    required this.mediaUrls,
  });

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      answerId: json['answerId'] as int,
      content: json['content'] as String,
      authorNickname: json['authorNickname'] as String,
      authorTrustScore: json['authorTrustScore'] as int,
      authorExperience: json['authorExperience'] as String,
      isAccepted: json['isAccepted'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      mediaUrls: List<String>.from(json['mediaUrls'] ?? []),
    );
  }
}

/// 🔍 2-3. 질문 상세 모델
class QuestionDetail {
  final int questionId;
  final String title;
  final String content;
  final String category;
  final DateTime createdAt;
  final String authorNickname;
  final int likeCount;
  final bool isLiked;
  final double latitude;
  final double longitude;
  final List<String> mediaUrls;
  final List<Answer> answers;

  QuestionDetail({
    required this.questionId,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.authorNickname,
    required this.likeCount,
    required this.isLiked,
    required this.latitude,
    required this.longitude,
    required this.mediaUrls,
    required this.answers,
  });

  factory QuestionDetail.fromJson(Map<String, dynamic> json) {
    final List<dynamic> answerList = json['answers'] ?? [];
    return QuestionDetail(
      questionId: json['questionId'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      authorNickname: json['authorNickname'] as String,
      likeCount: json['likeCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      mediaUrls: List<String>.from(json['mediaUrls'] ?? []),
      answers: answerList
          .map((item) => Answer.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
