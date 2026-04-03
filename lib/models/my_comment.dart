/// 유저 활동용 댓글 모델
class MyComment {
  final String postId;
  final String postTitle;
  final String content;
  final DateTime createdAt;

  const MyComment({
    required this.postId,
    required this.postTitle,
    required this.content,
    required this.createdAt,
  });

  factory MyComment.fromJson(Map<String, dynamic> json) {
    return MyComment(
      postId:    json['questionId']?.toString()
                ?? json['postId']?.toString()
                ?? json['answerId']?.toString()
                ?? '',
      postTitle: json['questionTitle'] as String?
                ?? json['postTitle'] as String?
                ?? json['title'] as String?
                ?? '',
      content:   json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
