import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/community_post.dart';
import '../services/api_service.dart';
import 'community_filter_screen.dart';
import 'write_post_screen.dart';
import 'sign_in_screen.dart';
import 'post_detail_screen.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  final ApiService _api = ApiService();

  String _keyword = '';
  bool _onlyVerified = false;
  Set<String> _filterCategories = {};
  Set<String> _filterCountries  = {};

  String _sortOrder = '최신순';
  String _period    = '전체';

  List<CommunityPost> _posts      = [];
  List<CommunityPost> _allFetched = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  // ── API 호출 ─────────────────────────────────────────────────────
  Future<void> _fetchPosts({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);

    try {
      String? mappedCategory;
      if (_filterCategories.isNotEmpty) {
        final cat = _filterCategories.first;
        if (cat == '위험/주의') mappedCategory = 'DANGER';
        else if (cat == '문화') mappedCategory = 'CULTURE';
        else if (cat == '맛집/물가' || cat == '카페') mappedCategory = 'PRICE';
        else if (cat == '기타' || cat == '꿀팁') mappedCategory = 'ETC';
      }

      final fetched = await _api.getQuestions(category: mappedCategory, size: 20);
      debugPrint('[QaScreen] 불러온 게시글 수: ${fetched.length}');

      // SharedPreferences에 캐시된 위치 정보 주입
      final prefs = await SharedPreferences.getInstance();

      // [DEBUG] 저장된 location 키 전체 출력 (문제 진단용)
      final allKeys = prefs.getKeys().where((k) => k.startsWith('location_')).toList();
      debugPrint('[QaScreen] 저장된 위치 캐시 키 목록: $allKeys');
      debugPrint('[QaScreen] 게시글 questionId 목록: ${fetched.map((p) => p.questionId).toList()}');
      final withLocation = fetched.map((post) {
        // 이미 서버에서 locationKeyword를 받은 경우
        if (post.locationKeyword != null && post.locationKeyword!.isNotEmpty) {
          debugPrint('[QaScreen] 서버 위치: ${post.questionId} → ${post.locationKeyword}');
          return post;
        }
        // questionId 기반 캐시 확인
        final cachedById = prefs.getString('location_${post.questionId}');
        if (cachedById != null && cachedById.isNotEmpty) {
          debugPrint('[QaScreen] 캐시(ID) 위치: ${post.questionId} → $cachedById');
          return post.copyWith(locationKeyword: cachedById);
        }
        // 제목 해시 기반 임시 캐시 확인 (newId 없이 저장된 경우)
        final titleKey = post.title.hashCode.toString();
        final cachedByTitle = prefs.getString('location_title_$titleKey');
        if (cachedByTitle != null && cachedByTitle.isNotEmpty) {
          debugPrint('[QaScreen] 캐시(제목) 위치: ${post.title} → $cachedByTitle');
          // 정식 키로 이전 저장
          prefs.setString('location_${post.questionId}', cachedByTitle);
          return post.copyWith(locationKeyword: cachedByTitle);
        }
        return post;
      }).toList();

      if (mounted) {
        _allFetched = withLocation;
        _applySort();
      }
    } catch (e) {
      debugPrint('[QaScreen] 로드 오류: $e');
      if (mounted && !isSilent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게시글을 불러오지 못했습니다: $e'), duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted && !isSilent) setState(() => _isLoading = false);
    }
  }

  // ── 정렬 및 기간 필터 적용 ────────────────────────────────────────
  void _applySort() {
    List<CommunityPost> result = List.from(_allFetched);

    if (_period != '전체') {
      final now = DateTime.now();
      result = result.where((p) {
        try {
          final dt = DateTime.parse(p.createdAt);
          if (_period == '오늘') return now.difference(dt).inHours < 24;
          if (_period == '이번주') return now.difference(dt).inDays < 7;
          if (_period == '이번달') return now.difference(dt).inDays < 30;
        } catch (_) {}
        return true;
      }).toList();
    }

    if (_sortOrder == '인기순') {
      result.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    } else {
      result.sort((a, b) {
        try {
          return DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt));
        } catch (_) { return 0; }
      });
    }

    setState(() => _posts = result);
  }

  // ── 필터 화면 ────────────────────────────────────────────────────
  void _openFilterScreen() async {
    final result = await Navigator.push<CommunityFilterResult>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityFilterScreen(
          initialKeyword: _keyword,
          initialOnlyVerified: _onlyVerified,
          initialCategories: _filterCategories,
          initialCountries: _filterCountries,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _keyword = result.keyword;
        _onlyVerified = result.onlyVerified;
        _filterCategories = result.selectedCategories;
        _filterCountries = result.selectedCountries;
      });
      _fetchPosts();
    }
  }

  void _openSearchScreen() => _openFilterScreen();

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
          IconButton(
            onPressed: _openSearchScreen,
            icon: const Icon(Icons.search, color: Colors.black),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_outlined, color: Colors.black),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 정렬기준 + 기간 칩 (좌측 정렬) ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                _selectChip(
                  value: _sortOrder,
                  items: const ['최신순', '인기순'],
                  onChanged: (val) {
                    setState(() => _sortOrder = val);
                    _applySort();
                  },
                ),
                const SizedBox(width: 8),
                _selectChip(
                  value: _period,
                  items: const ['전체', '오늘', '이번주', '이번달'],
                  onChanged: (val) {
                    setState(() => _period = val);
                    _applySort();
                  },
                ),
              ],
            ),
          ),

          // 활성 필터 요약 칩 (있을 경우만)
          if (_onlyVerified || _filterCategories.isNotEmpty || _filterCountries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_onlyVerified)
                      _summaryChip('인증 사용자', Colors.black, Colors.white, onDelete: () {
                        setState(() => _onlyVerified = false);
                        _fetchPosts();
                      }),
                    ..._filterCategories.map((c) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _summaryChip(c, const Color(0xFFFFD54F), Colors.black, onDelete: () {
                        setState(() => _filterCategories.remove(c));
                        _fetchPosts();
                      }),
                    )),
                    ..._filterCountries.map((c) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _summaryChip(c, const Color(0xFFFFD54F), Colors.black, onDelete: () {
                        setState(() => _filterCountries.remove(c));
                      }),
                    )),
                  ],
                ),
              ),
            ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

          // ── 게시글 목록 ────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.article_outlined, size: 52, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              '아직 게시물이 없습니다.',
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
                          itemBuilder: (context, index) => _PostCard(post: _posts[index]),
                        ),
                      ),
          ),
        ],
      ),

      // ── 글 작성 FAB ────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ctx = context;
          final loggedIn = await _api.isLoggedIn();
          if (!mounted) return;

          if (!loggedIn) {
            Navigator.push(ctx, MaterialPageRoute(builder: (_) => const SignInScreen()));
            return;
          }

          final result = await Navigator.push<bool>(
            ctx,
            MaterialPageRoute(builder: (_) => const WritePostScreen()),
          );
          if (result == true && mounted) {
            setState(() {
              _keyword = '';
              _onlyVerified = false;
              _filterCategories = {};
              _filterCountries = {};
            });
            await _fetchPosts();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('게시물이 등록되었습니다! 🎉'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.black87,
                ),
              );
            }
          }
        },
        backgroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_outlined, color: Colors.black),
      ),
    );
  }

  // ── 탭 가능한 선택 칩 (바텀시트 선택) ──────────────────────────────
  Widget _selectChip({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          backgroundColor: Colors.white,
          builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 8),
              ...items.map((item) => ListTile(
                title: Text(
                  item,
                  style: TextStyle(
                    fontWeight: item == value ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
                trailing: item == value ? const Icon(Icons.check, color: Colors.black) : null,
                onTap: () {
                  Navigator.pop(context);
                  onChanged(item);
                },
              )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDDDDD)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black)),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down, size: 15, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  // ── 필터 요약 칩 ─────────────────────────────────────────────────
  Widget _summaryChip(String label, Color bgColor, Color textColor, {VoidCallback? onDelete}) {
    return Container(
      padding: EdgeInsets.only(left: 10, right: onDelete != null ? 4 : 10, top: 6, bottom: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.bold)),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            GestureDetector(onTap: onDelete, child: Icon(Icons.close, size: 13, color: textColor)),
          ],
        ],
      ),
    );
  }
}

// ── 게시글 카드 위젯 ─────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final CommunityPost post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final hasThumbnail = post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty;
    final hasLocation = post.locationKeyword != null && post.locationKeyword!.isNotEmpty;

    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 왼쪽: 텍스트 영역 ─────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 유저명 + 인증 마크
                    Row(
                      children: [
                        Text(
                          post.username,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w400),
                        ),
                        if (post.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: Color(0xFF29B6F6)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 제목
                    Text(
                      post.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // 내용 미리보기
                    Text(
                      post.preview,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    const SizedBox(height: 12),

                    // 메타 정보
                    Row(
                      children: [
                        Text(post.timeAgo, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        const SizedBox(width: 12),
                        _metaIcon(post.isLiked ? Icons.favorite : Icons.favorite_border, post.likes),
                        const SizedBox(width: 10),
                        _metaIcon(Icons.chat_bubble_outline, post.comments),
                        const SizedBox(width: 10),
                        _metaIcon(Icons.bookmark_border, post.bookmarks),
                      ],
                    ),
                  ],
                ),
              ),

              // ── 오른쪽: 이미지(있을 때) + 위치 항상 하단 ─────────
              if (hasThumbnail || hasLocation) ...[
                const SizedBox(width: 14),
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 썸네일
                    if (hasThumbnail)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          post.thumbnailUrl!,
                          width: 80, height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.image_outlined, color: Colors.grey),
                          ),
                        ),
                      ),

                    // 위치 정보 — 이미지 있으면 아래, 없어도 같은 위치(하단)
                    if (hasLocation) ...[
                      if (hasThumbnail) const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Color(0xFFFFD54F), shape: BoxShape.circle),
                            child: const Icon(Icons.location_on, size: 9, color: Colors.white),
                          ),
                          const SizedBox(width: 3),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 76),
                            child: Text(
                              post.locationKeyword!,
                              style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaIcon(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text('$count', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}
