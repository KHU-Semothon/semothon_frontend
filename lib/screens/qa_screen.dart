import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../services/api_service.dart';
import 'community_filter_screen.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  final ApiService _api = ApiService();

  String _sortLabel = '정렬 기준';
  String _periodLabel = '기간';
  String _countryTag = '일본';

  Set<String> _filterCategories = {};
  Set<String> _filterCountries  = {'일본'};

  List<CommunityPost> _posts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  // ── API 호출 ──────────────────────────────────────────────────
  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await _api.getPosts(
        categories: _filterCategories,
        countries:  _filterCountries,
        sort: _sortToKey(_sortLabel),
      );
      if (mounted) setState(() => _posts = fetched);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게시글을 불러오지 못했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _sortToKey(String label) {
    switch (label) {
      case '인기순': return 'popular';
      case '댓글순': return 'comments';
      default:       return 'latest';
    }
  }

  // ── 정렬 바텀시트 ─────────────────────────────────────────────
  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              _sheetItem('최신순'),
              _sheetItem('인기순'),
              _sheetItem('댓글순'),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // ── 기간 바텀시트 ─────────────────────────────────────────────
  void _showPeriodBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              _sheetItem('오늘', isPeriod: true),
              _sheetItem('이번 주', isPeriod: true),
              _sheetItem('이번 달', isPeriod: true),
              _sheetItem('전체', isPeriod: true),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetItem(String label, {bool isPeriod = false}) {
    return ListTile(
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        setState(() {
          if (isPeriod) { _periodLabel = label; }
          else          { _sortLabel   = label; }
        });
        _fetchPosts(); // 정렬/기간 바뀌면 다시 불러오기
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '커뮤니티',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search, color: Colors.black)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_outlined, color: Colors.black)),
        ],
      ),
      body: Column(
        children: [
          // ── 필터 바 ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showSortBottomSheet,
                  child: _filterChip(_sortLabel, hasArrow: true),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showPeriodBottomSheet,
                  child: _filterChip(_periodLabel, hasArrow: true),
                ),
                const SizedBox(width: 8),
                // 필터 아이콘 → 필터 화면으로 이동
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push<CommunityFilterResult>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommunityFilterScreen(
                          initialCategories: _filterCategories,
                          initialCountries:  _filterCountries,
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _filterCategories = result.selectedCategories;
                        _filterCountries  = result.selectedCountries;
                        _countryTag = _filterCountries.isNotEmpty
                            ? _filterCountries.first
                            : '';
                      });
                      _fetchPosts(); // 필터 변경 후 새로 불러오기
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: (_filterCategories.isNotEmpty || _filterCountries.isNotEmpty)
                            ? Colors.black
                            : const Color(0xFFDDDDDD),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: (_filterCategories.isNotEmpty || _filterCountries.isNotEmpty)
                          ? Colors.black
                          : Colors.white,
                    ),
                    child: Icon(
                      Icons.tune,
                      size: 16,
                      color: (_filterCategories.isNotEmpty || _filterCountries.isNotEmpty)
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
                const Spacer(),
                // 국가 태그
                if (_countryTag.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _filterCountries.length > 1
                              ? '$_countryTag 외 ${_filterCountries.length - 1}'
                              : _countryTag,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _filterCountries.clear();
                              _countryTag = '';
                            });
                            _fetchPosts();
                          },
                          child: const Icon(Icons.close, size: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

          // ── 게시글 목록 ──────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 52, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              '해당 필터에 맞는 게시물이 없습니다.',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchPosts,
                        child: ListView.separated(
                          itemCount: _posts.length,
        separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                          itemBuilder: (context, index) {
                            return _PostCard(post: _posts[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),

      // ── 글 작성 FAB ──────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_outlined, color: Colors.black),
      ),
    );
  }

  Widget _filterChip(String label, {bool hasArrow = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          if (hasArrow) ...[
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down, size: 15, color: Colors.black),
          ],
        ],
      ),
    );
  }
}

// ── 게시글 카드 위젯 ────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final CommunityPost post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 유저명 + 인증 점
                  Row(
                    children: [
                      Text(post.username, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      if (post.isVerified) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 7, height: 7,
                          decoration: const BoxDecoration(color: Color(0xFF29B6F6), shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(post.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(post.preview, style: const TextStyle(fontSize: 12, color: Color(0xFF999999), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  // 메타 (시간, 좋아요, 댓글, 저장)
                  Row(
                    children: [
                      Text(post.timeAgo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 12),
                      const Icon(Icons.favorite_border, size: 13, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text('${post.likes}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 10),
                      const Icon(Icons.chat_bubble_outline, size: 13, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text('${post.comments}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 10),
                      const Icon(Icons.bookmark_border, size: 13, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text('${post.bookmarks}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            if (post.hasThumbnail) ...[
              const SizedBox(width: 12),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.image_outlined, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
