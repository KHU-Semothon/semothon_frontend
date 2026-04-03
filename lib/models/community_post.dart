/// 커뮤니티 게시글 모델
/// 서버 연동 시 toJson/fromJson을 그대로 사용하면 됩니다.
class CommunityPost {
  final String questionId;    // 명세서: questionId
  final String authorNickname; // 명세서: authorNickname
  final bool isVerified;
  final String title;
  final String content;      // preview 대신 content 사용 가능
  final String createdAt;    // 명세서: createdAt (String)
  final int likeCount;       // 명세서: likeCount
  final int answerCount;     // 명세서: answerCount
  final String? thumbnailUrl; // 명세서: thumbnailUrl
  final List<String> mediaUrls; // 명세서: mediaUrls
  final String category;
  final String? locationKeyword;
  
  final bool isLiked;
  final bool isCommented;
  final bool isBookmarked;
  final double? authorTrustScore;
  final int?    authorLivingYears;
  final int?    authorVisitCount;

  // 위치 정보 (선택 사항)
  final double? latitude;
  final double? longitude;
  final String? address;

  // 명세서 4-1: /api/v1/posts 응답에 포함된 서버 측 timeAgo 문자열 (선택)
  final String? _rawTimeAgo;

  const CommunityPost({
    required this.questionId,
    required this.authorNickname,
    this.isVerified = false,
    required this.title,
    required this.content,
    required this.createdAt,
    this.likeCount = 0,
    this.answerCount = 0,
    this.thumbnailUrl,
    this.mediaUrls = const [],
    required this.category,
    this.locationKeyword,
    this.isLiked = false,
    this.isCommented = false,
    this.isBookmarked = false,
    this.authorTrustScore,
    this.authorLivingYears,
    this.authorVisitCount,
    this.latitude,
    this.longitude,
    this.address,
    String? rawTimeAgo,
  }) : _rawTimeAgo = rawTimeAgo;

  // 호환성을 위한 게터
  String get id => questionId;
  String get username => authorNickname;
  String get preview => content.length > 100 ? content.substring(0, 100) : content;
  int get likes => likeCount;
  int get comments => answerCount;
  int get bookmarks => 0; // 명세서에 없음
  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
  /// 서버에서 timeAgo 를 직접 받은 경우 그 값을 우선 사용하고, 없으면 createdAt 으로 계산
  String get timeAgo {
    final raw = _rawTimeAgo;
    return (raw != null && raw.isNotEmpty) ? raw : _parseTimeAgo(createdAt);
  }
  String get country => locationKeyword ?? '';

  // ── 서버 → 앱 (JSON 역직렬화) ─────────────────────────────────
  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      questionId:      json['questionId']?.toString() ?? json['id']?.toString() ?? '',
      authorNickname:  json['authorNickname'] as String? ?? json['username'] as String? ?? '',
      isVerified:      json['isVerified'] as bool? ?? false,
      title:           json['title'] as String? ?? '',
      content:         json['content'] as String? ?? json['preview'] as String? ?? '',
      createdAt:       json['createdAt'] as String? ?? '',
      likeCount:       (json['likeCount'] as num?)?.toInt() ?? (json['likes'] as num?)?.toInt() ?? 0,
      answerCount:     (json['answerCount'] as num?)?.toInt() ?? (json['comments'] as num?)?.toInt() ?? 0,
      thumbnailUrl:    json['thumbnailUrl'] as String?,
      mediaUrls:       (json['mediaUrls'] as List?)?.map((e) => e.toString()).toList() ?? [],
      category:        json['category'] as String? ?? '',
      locationKeyword: json['locationKeyword'] as String? ?? json['country'] as String?,
      isLiked:         json['isLiked'] as bool? ?? false,
      isCommented:     json['isCommented'] as bool? ?? false,
      isBookmarked:    json['isBookmarked'] as bool? ?? false,
      authorTrustScore: (json['authorTrustScore'] as num?)?.toDouble(),
      latitude:        (json['latitude']  as num?)?.toDouble(),
      longitude:       (json['longitude'] as num?)?.toDouble(),
      address:         json['address']    as String?,
      // 명세서 4-1: /api/v1/posts 응답의 timeAgo 필드 지원
      rawTimeAgo:      json['timeAgo'] as String?,
    );
  }

  static String _parseTimeAgo(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      return '${diff.inDays}일 전';
    } catch (_) {
      return dateStr;
    }
  }

  // ── 앱 → 서버 (JSON 직렬화) ───────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id':           id,
    'username':     username,
    'isVerified':   isVerified,
    'isLiked':      isLiked,
    'isCommented':  isCommented,
    'isBookmarked': isBookmarked,
    'title':        title,
    'preview':      preview,
    'likes':        likes,
    'comments':     comments,
    'bookmarks':    bookmarks,
    'hasThumbnail': hasThumbnail,
    'createdAt':    createdAt,
    'category':     category,
    'country':      country,
    if (latitude != null)  'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (address != null)   'address': address,
  };

  /// locationKeyword 등 특정 필드만 교체한 복사본 반환
  CommunityPost copyWith({
    String? locationKeyword,
    String? address,
    double? latitude,
    double? longitude,
    bool? isLiked,
    bool? isBookmarked,
    int? likeCount,
  }) {
    return CommunityPost(
      questionId:       questionId,
      authorNickname:   authorNickname,
      isVerified:       isVerified,
      title:            title,
      content:          content,
      createdAt:        createdAt,
      likeCount:        likeCount ?? this.likeCount,
      answerCount:      answerCount,
      thumbnailUrl:     thumbnailUrl,
      mediaUrls:        mediaUrls,
      category:         category,
      locationKeyword:  locationKeyword ?? this.locationKeyword,
      isLiked:          isLiked ?? this.isLiked,
      isCommented:      isCommented,
      isBookmarked:     isBookmarked ?? this.isBookmarked,
      authorTrustScore: authorTrustScore,
      authorLivingYears:authorLivingYears,
      authorVisitCount: authorVisitCount,
      latitude:         latitude ?? this.latitude,
      longitude:        longitude ?? this.longitude,
      address:          address ?? this.address,
      rawTimeAgo:       _rawTimeAgo,
    );
  }
}
