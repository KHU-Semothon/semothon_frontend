import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../models/save_folder.dart';
import '../services/api_service.dart';
import 'sign_in_screen.dart';

// ── 댓글 임시 모델 ─────────────────────────────────────────────
class _Comment {
  final String id;
  final String username;
  final String userSubtitle;
  final String text;
  final String timeAgo;
  int likes;
  final int replyCount;

  _Comment({
    required this.id,
    required this.username,
    required this.userSubtitle,
    required this.text,
    required this.timeAgo,
    this.likes = 0,
    this.replyCount = 0,
  });
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
  int _likeCount = 0;
  bool _isReported = false;
  // 작성자 신뢰도 (서버 응답 기본값: 90%)
  late double _authorTrustScore;

  final List<_Comment> _comments = [];

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likes;
    // 서버에서 내려올 때 authorTrustScore 사용, 없으면 기본값 90
    _authorTrustScore = widget.post.authorTrustScore ?? 90.0;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 댓글 불러오기 (서버가 응답 없으면 빈 리스트)
  Future<void> _loadComments() async {
    // TODO: 실제 서버 연동 시 api.getComments(widget.post.id) 사용
    // 현재는 빈 상태로 시작
    setState(() {});
  }

  // ── 좋아요 ───────────────────────────────────────────────────
  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
  }

  // ── 신고 ─────────────────────────────────────────────────────
  Future<void> _handleReport() async {
    if (_isReported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 신고한 게시물입니다.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('게시물 신고', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: const Text('이 게시물을 신고하시겠습니까?\n신고 시 작성자의 신뢰도가 10% 낮아집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('신고', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _api.reportPost(widget.post.id);
    } catch (_) {
      // 서버 실패해도 로컬 반영
    }
    if (!mounted) return;
    setState(() {
      _isReported = true;
      _authorTrustScore = (_authorTrustScore - 10).clamp(0, 100);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('신고가 접수되었습니다.'), behavior: SnackBarBehavior.floating),
    );
  }

  // ── 작성자 프로필 팝업 ─────────────────────────────────────────
  void _showAuthorProfile() {
    final post = widget.post;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들 바
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              // 아바타 + 이름
              const CircleAvatar(
                radius: 36,
                backgroundColor: Color(0xFFD0D0D0),
                child: Icon(Icons.person, size: 38, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(post.username,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (post.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 16, color: Color(0xFF29B6F6)),
                  ],
                ],
              ),
              // 거주/방문 정보
              const SizedBox(height: 4),
              Text(
                _buildAuthorSubtitle(post),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              // 신뢰도 바
              Row(
                children: [
                  const Text('신뢰도', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(
                    '${_authorTrustScore.toInt()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _authorTrustScore >= 70
                          ? Colors.green
                          : _authorTrustScore >= 40 ? Colors.orange : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _authorTrustScore / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _authorTrustScore >= 70
                        ? Colors.green
                        : _authorTrustScore >= 40 ? Colors.orange : Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // 작성자 부제 텍스트 생성
  String _buildAuthorSubtitle(CommunityPost post) {
    final parts = <String>[];
    if (post.authorLivingYears != null && post.authorLivingYears! > 0) {
      parts.add('${post.country} 거주 ${post.authorLivingYears}년');
    }
    if (post.authorVisitCount != null && post.authorVisitCount! > 0) {
      parts.add('방문 ${post.authorVisitCount}회');
    }
    if (parts.isEmpty && post.country.isNotEmpty) return '${post.country} 방문';
    return parts.join(' · ');
  }

  // ── 저장 (폴더 선택) ─────────────────────────────────────────
  Future<void> _handleSave() async {
    final loggedIn = await _api.isLoggedIn();
    if (!mounted) return;

    if (!loggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );
      return;
    }

    // 폴더 목록 불러오기
    List<SaveFolder> folders = [];
    try {
      folders = await _api.getFolders();
    } catch (_) {}

    if (!mounted) return;

    // 폴더 선택 바텀시트
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FolderPickerSheet(
        folders: folders,
        onFolderSelected: (folder) async {
          Navigator.pop(ctx);
          try {
            // 실제 서버 연동: POST /api/v1/folders/{folderId}/posts/{postId}
            await _api.addPostToFolder(folder.id, widget.post.id);
            setState(() => _isBookmarked = true);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${folder.name}"에 저장되었습니다.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('저장 실패: $e')),
              );
            }
          }
        },
        onCreateFolder: () async {
          Navigator.pop(ctx);
          // 새 폴더 이름 입력 다이얼로그
          final name = await _showCreateFolderDialog();
          if (name != null && name.isNotEmpty && mounted) {
            try {
              // 1. 새 폴더 생성
              final newFolder = await _api.createFolder(name);
              // 2. 새 폴더에 게시글 저장: POST /api/v1/folders/{folderId}/posts/{postId}
              await _api.addPostToFolder(newFolder.id, widget.post.id);
              setState(() => _isBookmarked = true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"$name" 폴더에 저장되었습니다.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('저장 실패: $e')),
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
        title: const Text('새 폴더', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '폴더 이름',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.black),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('만들기', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // ── 댓글 제출 ──────────────────────────────────────────────
  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    final loggedIn = await _api.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen()));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // TODO: 실제 서버 연동 시 api.createComment(postId, text)
      final newComment = _Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: '나',
        userSubtitle: '',
        text: text,
        timeAgo: '방금',
        likes: 0,
        replyCount: 0,
      );
      setState(() {
        _comments.add(newComment);
        _commentController.clear();
      });
      _commentFocus.unfocus();

      // 스크롤 하단으로
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
        title: const Text(
          '커뮤니티',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isReported ? Icons.flag : Icons.flag_outlined,
              color: _isReported ? Colors.red : Colors.black,
            ),
            tooltip: '신고',
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
                // ── 게시글 본체 ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 작성자 정보
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _showAuthorProfile,
                            child: const CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xFFD0D0D0),
                              child: Icon(Icons.person, color: Colors.white, size: 22),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(post.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  if (post.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, size: 14, color: Color(0xFF29B6F6)),
                                  ],
                                ],
                              ),
                              Text(
                                _buildAuthorSubtitle(post),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 태그 (국가 + 카테고리)
                      Wrap(
                        spacing: 6,
                        children: [
                          if (post.country.isNotEmpty) _buildTag(post.country),
                          if (post.category.isNotEmpty) _buildTag(post.category),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 제목
                      Text(
                        post.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black, height: 1.4),
                      ),
                      const SizedBox(height: 10),

                      // 본문
                      Text(
                        post.preview,
                        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.65),
                      ),
                      const SizedBox(height: 14),

                      // 시간 + 위치
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(post.timeAgo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          if (post.address != null && post.address!.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 13, color: Colors.grey),
                                const SizedBox(width: 2),
                                Text(
                                  post.address!.length > 12 ? '${post.address!.substring(0, 12)}...' : post.address!,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── 좋아요 / 댓글 / 저장 액션 바 ────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 좋아요
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Row(
                          children: [
                            Icon(
                              _isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 20,
                              color: _isLiked ? Colors.red : Colors.black54,
                            ),
                            const SizedBox(width: 5),
                            Text('좋아요 $_likeCount', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // 댓글
                      GestureDetector(
                        onTap: () => _commentFocus.requestFocus(),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.black54),
                            const SizedBox(width: 5),
                            Text('댓글 ${_comments.length}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // 저장
                      GestureDetector(
                        onTap: _handleSave,
                        child: Row(
                          children: [
                            Icon(
                              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                              size: 20,
                              color: _isBookmarked ? Colors.black : Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            const Text('저장', style: TextStyle(fontSize: 13, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 댓글 목록 ─────────────────────────────────
                if (_comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('첫 댓글을 남겨보세요', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ),
                  )
                else
                  ..._comments.map((c) => _CommentItem(
                    comment: c,
                    onLike: () => setState(() => c.likes++),
                    onReply: () => _commentFocus.requestFocus(),
                  )),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── 댓글 입력바 ──────────────────────────────────────
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
              12, 8, 12, MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 20,
            ),
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
                  onTap: _commentController.text.trim().isNotEmpty ? _submitComment : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _commentController.text.trim().isNotEmpty ? Colors.black : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: _commentController.text.trim().isNotEmpty ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 댓글 아이템 위젯
// ─────────────────────────────────────────────────────────────
class _CommentItem extends StatelessWidget {
  final _Comment comment;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _CommentItem({required this.comment, required this.onLike, required this.onReply});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFD0D0D0),
                child: Icon(Icons.person, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 이름 + 부제
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(comment.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            if (comment.userSubtitle.isNotEmpty)
                              Text(comment.userSubtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        // 좋아요
                        GestureDetector(
                          onTap: onLike,
                          child: Row(
                            children: [
                              const Icon(Icons.favorite_border, size: 14, color: Colors.grey),
                              const SizedBox(width: 3),
                              Text('${comment.likes}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(comment.text, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(comment.timeAgo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: onReply,
                          child: const Text('답글', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                    if (comment.replyCount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(width: 14, height: 1, color: Colors.grey[400]),
                          const SizedBox(width: 6),
                          Text('· 답글 ${comment.replyCount}개', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 폴더 선택 바텀시트
// ─────────────────────────────────────────────────────────────
class _FolderPickerSheet extends StatelessWidget {
  final List<SaveFolder> folders;
  final void Function(SaveFolder) onFolderSelected;
  final VoidCallback onCreateFolder;

  const _FolderPickerSheet({
    required this.folders,
    required this.onFolderSelected,
    required this.onCreateFolder,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('폴더에 저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),

          // 새 폴더 만들기
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: Colors.black54),
            ),
            title: const Text('새 폴더 만들기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            onTap: onCreateFolder,
          ),

          if (folders.isNotEmpty) const Divider(height: 1, indent: 20, endIndent: 20),

          // 기존 폴더 목록
          ...folders.map((f) => ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder_outlined, color: Colors.black54),
            ),
            title: Text(f.name, style: const TextStyle(fontSize: 14)),
            subtitle: Text('게시물 ${f.postCount}개', style: const TextStyle(fontSize: 12)),
            onTap: () => onFolderSelected(f),
          )),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
