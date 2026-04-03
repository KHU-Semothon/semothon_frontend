import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../models/save_folder.dart';
import '../services/api_service.dart';
import 'sign_in_screen.dart';

// ── 댓글 모델 ───────────────────────────────────────────────────
class _Comment {
  final String answerId;
  final String authorNickname;
  final String content;
  final String createdAt;
  int likeCount;
  final bool isAccepted;
  final int? replyCount;

  _Comment({
    required this.answerId,
    required this.authorNickname,
    required this.content,
    required this.createdAt,
    this.likeCount = 0,
    this.isAccepted = false,
    this.replyCount,
  });

  String get timeAgo => _parseTimeAgo(createdAt);

  static String _parseTimeAgo(String dateStr) {
    if (dateStr.isEmpty) return '방금 전';
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      return '${diff.inDays}일 전';
    } catch (_) { return dateStr; }
  }
}

// ─────────────────────────────────────────────────────────────
// 게시글 상세 화면
// ─────────────────────────────────────────────────────────────
class PostDetailScreen extends StatefulWidget {
  final CommunityPost post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isLiked = false;
  bool _isBookmarked = false;
  bool _isSubmitting = false;
  bool _isReported = false;
  int _likeCount = 0;
  String? _locationKeyword;   // 상세 API에서 로드
  late double _authorTrustScore;
  final List<_Comment> _comments = [];

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likes;
    _isLiked = widget.post.isLiked;
    _isBookmarked = widget.post.isBookmarked;
    _authorTrustScore = widget.post.authorTrustScore ?? 90.0;
    _locationKeyword = widget.post.locationKeyword; // 초기값: 목록에서 전달된 값
    _refreshDetail();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshDetail() async {
    try {
      final detail = await _api.getQuestionDetail(widget.post.id);
      debugPrint('[refreshDetail] keys: ${detail.keys.toList()}');

      if (mounted) {
        setState(() {
          _isLiked   = detail['isLiked']   as bool? ?? _isLiked;
          _likeCount = (detail['likeCount'] as num?)?.toInt() ?? _likeCount;

          // 상세 API에서 locationKeyword 추출
          final detailLocation = detail['locationKeyword'] as String?;
          if (detailLocation != null && detailLocation.isNotEmpty) {
            _locationKeyword = detailLocation;
          }

          // 서버가 다양한 키로 댓글 목록을 반환할 수 있음
          final answersRaw = detail['answers']
              ?? detail['comments']
              ?? detail['answerList']
              ?? detail['answerResponses']
              ?? [];
          debugPrint('[refreshDetail] answersRaw type: ${answersRaw.runtimeType}, count: ${(answersRaw as List?)?.length ?? 0}');

          final answersData = answersRaw is List ? answersRaw : [];
          _comments.clear();
          for (var item in answersData) {
            final json = item as Map<String, dynamic>;
            _comments.add(_Comment(
              answerId:       json['answerId']?.toString() ?? json['id']?.toString() ?? '',
              authorNickname: json['authorNickname'] as String? ?? json['nickname'] as String? ?? '익명',
              content:        json['content'] as String? ?? '',
              createdAt:      json['createdAt'] as String? ?? '',
              likeCount:      (json['likeCount'] as num?)?.toInt() ?? 0,
              isAccepted:     json['isAccepted'] as bool? ?? false,
              replyCount:     (json['replyCount'] as num?)?.toInt(),
            ));
          }
          debugPrint('[refreshDetail] 파싱된 댓글 수: ${_comments.length}');
        });
      }
    } catch (e) {
      debugPrint('[refreshDetail] 오류: $e');
    }
  }

  // ── 좋아요 ────────────────────────────────────────────────────
  Future<void> _toggleLike() async {
    final orig = _isLiked;
    final origCount = _likeCount;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      final result = await _api.toggleQuestionLike(widget.post.id);
      if (mounted) {
        setState(() {
          _isLiked   = result['isLiked']   as bool? ?? _isLiked;
          _likeCount = (result['likeCount'] as num?)?.toInt() ?? _likeCount;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLiked = orig; _likeCount = origCount; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('좋아요 실패: $e')));
      }
    }
  }

  // ── 신고 ─────────────────────────────────────────────────────
  Future<void> _handleReport() async {
    if (_isReported) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미 신고한 게시물입니다.')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('게시물 신고', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('이 게시물을 신고하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('신고', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try { await _api.reportPost(widget.post.id); } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isReported = true;
      _authorTrustScore = (_authorTrustScore - 10).clamp(0, 100);
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
  }

  // ── 저장 ─────────────────────────────────────────────────────
  Future<void> _handleSave() async {
    final loggedIn = await _api.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) { Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen())); return; }

    // 폴더 목록 로드
    List<SaveFolder> folders = [];
    try {
      folders = await _api.getFolders();
    } catch (e) {
      debugPrint('[handleSave] 폴더 로드 실패: $e');
      // 서버 실패시 빈 목록으로 진행 (새 폴더 만들기는 가능)
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _FolderPickerSheet(
        folders: folders,
        onFolderSelected: (folder) async {
          Navigator.pop(ctx);

          final folderId = folder.id;
          final postId   = widget.post.id;
          debugPrint('[handleSave] folderId="$folderId", postId="$postId"');

          // folderId/postId 비어있으면 에러 표시
          if (folderId.isEmpty || postId.isEmpty) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('저장 실패: ID 누락 (folderId=${folderId.isEmpty ? "없음" : folderId}, postId=${postId.isEmpty ? "없음" : postId})'),
                backgroundColor: Colors.red[700],
              ),
            );
            return;
          }

          // UI 선반영
          setState(() => _isBookmarked = true);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${folder.name}"에 저장되었습니다.')),
          );

          // 서버 비동기 저장
          try {
            await _api.addPostToFolder(folderId, postId);
            debugPrint('[handleSave] 서버 저장 완료');
          } catch (e) {
            debugPrint('[handleSave] 서버 저장 실패: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('서버 동기화 실패: $e'),
                  backgroundColor: Colors.orange[700],
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        },
        onCreateFolder: () async {
          Navigator.pop(ctx);
          final name = await _showCreateFolderDialog();
          if (name != null && name.isNotEmpty && mounted) {
            // UI 선반영
            setState(() => _isBookmarked = true);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('"$name" 폴더에 저장되었습니다.')),
            );
            // 서버 비동기 저장
            try {
              final newFolder = await _api.createFolder(name);
              debugPrint('[handleSave] 새 폴더 생성: id=${newFolder.id}');
              await _api.addPostToFolder(newFolder.id, widget.post.id);
              debugPrint('[handleSave] 새 폴더에 서버 저장 완료');
            } catch (e) {
              debugPrint('[handleSave] 새 폴더 서버 저장 실패: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('서버 동기화 실패: $e'),
                    backgroundColor: Colors.orange[700],
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }

  Future<String?> _showCreateFolderDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('새 폴더', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '폴더 이름',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('만들기', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // ── 댓글 제출 ─────────────────────────────────────────────────
  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;
    final loggedIn = await _api.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) { Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen())); return; }
    setState(() => _isSubmitting = true);
    try {
      debugPrint('[submitComment] questionId=${widget.post.id}, content=$text');
      await _api.postAnswer(widget.post.id, text);
      debugPrint('[submitComment] 등록 성공, 목록 새로고침');
      await _refreshDetail();
      if (mounted) { _commentController.clear(); _commentFocus.unfocus(); }
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      debugPrint('[submitComment] 실패: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('댓글 작성 실패: $e'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: '확인', textColor: Colors.white, onPressed: () {}),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── 카테고리/나라 한글 변환 ─────────────────────────────────
  static String _koreanLabel(String raw) {
    const map = {
      // 카테고리
      'DANGER':  '위험/주의',
      'CULTURE': '문화',
      'PRICE':   '맛집/물가',
      'CAFE':    '카페',
      'TIP':     '꿀팁',
      'ETC':     '기타',
      // 나라
      'JAPAN':   '일본',
      'VIETNAM': '베트남',
      'THAILAND':'태국',
      'TAIWAN':  '대만',
      'KOREA':   '한국',
      'EUROPE':  '유럽',
      'USA':     '미국',
    };
    return map[raw.toUpperCase()] ?? raw;
  }

  String _buildAuthorSubtitle(CommunityPost post) {
    final parts = <String>[];
    if (post.authorLivingYears != null && post.authorLivingYears! > 0) parts.add('${post.country} 거주 ${post.authorLivingYears}년');
    if (post.authorVisitCount != null && post.authorVisitCount! > 0) parts.add('방문 ${post.authorVisitCount}회');
    if (parts.isEmpty && post.country.isNotEmpty) return '${post.country} 방문';
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: const Text('커뮤니티', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black)),
        actions: [
          IconButton(
            icon: Icon(_isReported ? Icons.flag : Icons.flag_outlined, color: _isReported ? Colors.red : Colors.black),
            onPressed: _handleReport,
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: [
                // ── 게시글 본체 ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 작성자 정보
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 22,
                            backgroundColor: Color(0xFFD0D0D0),
                            child: Icon(Icons.person, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(post.username, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  if (post.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, size: 14, color: Color(0xFF29B6F6)),
                                  ],
                                ],
                              ),
                              Text(_buildAuthorSubtitle(post), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 태그 (외곽선 pill) - 서버 enum → 한글 변환
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (post.country.isNotEmpty) _buildOutlineTag(_koreanLabel(post.country)),
                          if (post.category.isNotEmpty) _buildOutlineTag(_koreanLabel(post.category)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 제목
                      Text(post.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black, height: 1.4)),
                      const SizedBox(height: 10),

                      // 본문
                      Text(post.content.isNotEmpty ? post.content : post.preview,
                          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.65)),
                      const SizedBox(height: 14),

                      // 이미지
                      if (post.mediaUrls.isNotEmpty)
                        SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: post.mediaUrls.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(post.mediaUrls[i], height: 180, width: 180, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      if (post.mediaUrls.isNotEmpty) const SizedBox(height: 14),

                      // 시간 + 위치
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(post.timeAgo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          if (_locationKeyword != null && _locationKeyword!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Color(0xFFFFD54F), shape: BoxShape.circle),
                                  child: const Icon(Icons.location_on, size: 10, color: Colors.white),
                                ),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  child: Text(
                                    _locationKeyword!,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // ── 액션 바 (좋아요 | 댓글 | 저장) ───────────
                Container(
                  height: 52,
                  decoration: const BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 좋아요
                      Expanded(
                        child: GestureDetector(
                          onTap: _toggleLike,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                                  size: 20, color: _isLiked ? Colors.red : Colors.black54),
                              const SizedBox(width: 6),
                              Text('좋아요 $_likeCount', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, height: 24, color: const Color(0xFFEEEEEE)),
                      // 댓글
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _commentFocus.requestFocus(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.black54),
                              const SizedBox(width: 6),
                              Text('댓글 ${_comments.length}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, height: 24, color: const Color(0xFFEEEEEE)),
                      // 저장
                      Expanded(
                        child: GestureDetector(
                          onTap: _handleSave,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                  size: 20, color: _isBookmarked ? Colors.black : Colors.black54),
                              const SizedBox(width: 6),
                              const Text('저장', style: TextStyle(fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 댓글 목록 ──────────────────────────────────
                if (_comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('첫 댓글을 남겨보세요', style: TextStyle(fontSize: 13, color: Colors.grey))),
                  )
                else
                  ..._comments.map((c) => _CommentItem(
                    comment: c,
                    onLike: () => setState(() => c.likeCount++),
                    onReply: () => _commentFocus.requestFocus(),
                  )),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // ── 댓글 입력바 ────────────────────────────────────
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(12, 8, 12,
                MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 20),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFD0D0D0),
                  child: Icon(Icons.person, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocus,
                      style: const TextStyle(fontSize: 14),
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: '댓글을 입력하세요...',
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _commentController.text.trim().isNotEmpty && !_isSubmitting ? _submitComment : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _commentController.text.trim().isNotEmpty && !_isSubmitting
                          ? Colors.black : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: _isSubmitting
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(Icons.send_rounded, size: 18,
                            color: _commentController.text.trim().isNotEmpty ? Colors.white : Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 외곽선 태그
  Widget _buildOutlineTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 댓글 아이템
// ─────────────────────────────────────────────────────────────
class _CommentItem extends StatelessWidget {
  final _Comment comment;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _CommentItem({required this.comment, required this.onLike, required this.onReply});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아바타
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFD0D0D0),
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              // 본문
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이름 + 경험 + 아이콘
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(comment.authorNickname,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              if (comment.isAccepted) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)),
                                  child: const Text('채택됨', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // ♡ · 💬
                        Row(
                          children: [
                            GestureDetector(
                              onTap: onLike,
                              child: Row(
                                children: [
                                  const Icon(Icons.favorite_border, size: 15, color: Colors.grey),
                                  const SizedBox(width: 3),
                                  Text('${comment.likeCount}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: onReply,
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline, size: 15, color: Colors.grey),
                                  if (comment.replyCount != null && comment.replyCount! > 0) ...[
                                    const SizedBox(width: 3),
                                    Text('${comment.replyCount}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 본문
                    Text(comment.content, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
                    const SizedBox(height: 6),
                    // 시간
                    Text(comment.timeAgo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    // 답글 표시
                    if (comment.replyCount != null && comment.replyCount! > 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('└', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(width: 8),
                          const CircleAvatar(radius: 8, backgroundColor: Color(0xFFD0D0D0),
                              child: Icon(Icons.person, size: 8, color: Colors.white)),
                          const SizedBox(width: 6),
                          Text('답글 ${comment.replyCount}개',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Divider(height: 1, color: Color(0xFFF5F5F5)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 폴더 선택 바텀시트
// ─────────────────────────────────────────────────────────────
class _FolderPickerSheet extends StatelessWidget {
  final List<SaveFolder> folders;
  final ValueChanged<SaveFolder> onFolderSelected;
  final VoidCallback onCreateFolder;

  const _FolderPickerSheet({
    required this.folders,
    required this.onFolderSelected,
    required this.onCreateFolder,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('저장할 폴더 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (folders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('저장된 폴더가 없습니다.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...folders.map((f) => ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f.name),
                onTap: () => onFolderSelected(f),
              )),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.black),
              title: const Text('새 폴더 만들기', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: onCreateFolder,
            ),
          ],
        ),
      ),
    );
  }
}
