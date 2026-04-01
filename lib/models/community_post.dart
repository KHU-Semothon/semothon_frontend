/// 커뮤니티 게시글 모델
/// 서버 연동 시 toJson/fromJson을 그대로 사용하면 됩니다.
class CommunityPost {
  final String id;
  final String username;
  final bool isVerified;
  final String title;
  final String preview; // 미리보기 본문
  final String timeAgo; // 서버에서 "N분 전" 형태로 내려주거나 클라이언트에서 계산
  final int likes;
  final int comments;
  final int bookmarks;
  final bool hasThumbnail;
  final String category; // 식당·화장실·쇼핑·유적
  final String country;  // 일본·중국·미국·영국
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.username,
    required this.isVerified,
    required this.title,
    required this.preview,
    required this.timeAgo,
    required this.likes,
    required this.comments,
    required this.bookmarks,
    required this.hasThumbnail,
    required this.category,
    required this.country,
    required this.createdAt,
  });

  // ── 서버 → 앱 (JSON 역직렬화) ─────────────────────────────────
  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id:           json['id']?.toString() ?? '',
      username:     json['username'] as String? ?? '',
      isVerified:   json['isVerified'] as bool? ?? false,
      title:        json['title'] as String? ?? '',
      preview:      json['preview'] as String? ?? json['content'] as String? ?? '',
      timeAgo:      json['timeAgo'] as String? ?? '',
      likes:        (json['likes'] as num?)?.toInt() ?? 0,
      comments:     (json['comments'] as num?)?.toInt() ?? 0,
      bookmarks:    (json['bookmarks'] as num?)?.toInt() ?? 0,
      hasThumbnail: json['hasThumbnail'] as bool? ?? false,
      category:     json['category'] as String? ?? '',
      country:      json['country'] as String? ?? '',
      createdAt:    DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // ── 앱 → 서버 (JSON 직렬화) ───────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id':           id,
    'username':     username,
    'isVerified':   isVerified,
    'title':        title,
    'preview':      preview,
    'likes':        likes,
    'comments':     comments,
    'bookmarks':    bookmarks,
    'hasThumbnail': hasThumbnail,
    'category':     category,
    'country':      country,
    'createdAt':    createdAt.toIso8601String(),
  };
}
