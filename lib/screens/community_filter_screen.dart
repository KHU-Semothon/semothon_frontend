import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommunityFilterResult {
  final String keyword;
  final bool onlyVerified;
  final Set<String> selectedCategories;
  final Set<String> selectedCountries;

  const CommunityFilterResult({
    required this.keyword,
    required this.onlyVerified,
    required this.selectedCategories,
    required this.selectedCountries,
  });
}

class CommunityFilterScreen extends StatefulWidget {
  final String initialKeyword;
  final bool initialOnlyVerified;
  final Set<String> initialCategories;
  final Set<String> initialCountries;

  const CommunityFilterScreen({
    super.key,
    required this.initialKeyword,
    required this.initialOnlyVerified,
    required this.initialCategories,
    required this.initialCountries,
  });

  @override
  State<CommunityFilterScreen> createState() => _CommunityFilterScreenState();
}

class _CommunityFilterScreenState extends State<CommunityFilterScreen> {
  static const String _prefsKey = 'community_recent_keywords';
  static const int _maxRecent = 3;

  final TextEditingController _searchController = TextEditingController();
  bool _onlyVerified = false;
  late Set<String> _selectedCategories;
  late Set<String> _selectedCountries;

  List<String> _recentKeywords = [];

  final Map<String, String> _categoryWithIcon = {
    '위험/주의': '⚠️',
    '문화': '🎎',
    '맛집/물가': '🍽️',
    '카페': '☕',
    '꿀팁': '📍',
    '기타': '☁️',
  };

  final List<String> _countries = ['일본', '베트남', '태국', '대만', '한국', '유럽', '미국'];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialKeyword;
    _onlyVerified = widget.initialOnlyVerified;
    _selectedCategories = Set.from(widget.initialCategories);
    _selectedCountries = Set.from(widget.initialCountries);
    _loadRecentKeywords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── SharedPreferences로 최근 검색어 불러오기 ─────────────
  Future<void> _loadRecentKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey) ?? [];
    if (mounted) {
      setState(() {
        _recentKeywords = saved;
      });
    }
  }

  // ── 검색어 저장 (최대 3개, 중복 제거, 최신이 앞으로) ──────
  Future<void> _saveKeyword(String keyword) async {
    if (keyword.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList(_prefsKey) ?? [];
    saved.remove(keyword); // 중복 제거
    saved.insert(0, keyword); // 맨 앞에 추가
    if (saved.length > _maxRecent) saved = saved.sublist(0, _maxRecent);
    await prefs.setStringList(_prefsKey, saved);
    if (mounted) setState(() => _recentKeywords = saved);
  }

  // ── 특정 검색어 삭제 ────────────────────────────────────
  Future<void> _removeKeyword(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList(_prefsKey) ?? [];
    saved.remove(keyword);
    await prefs.setStringList(_prefsKey, saved);
    if (mounted) setState(() => _recentKeywords = saved);
  }

  // ── 전체 검색어 삭제 ────────────────────────────────────
  Future<void> _clearAllKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    if (mounted) setState(() => _recentKeywords = []);
  }

  // ── 검색어 칩 클릭 시 텍스트 필드에 자동 입력 ─────────────
  void _onRecentKeywordTap(String keyword) {
    setState(() => _searchController.text = keyword);
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: keyword.length),
    );
  }

  void _apply() async {
    final keyword = _searchController.text.trim();
    if (keyword.isNotEmpty) {
      await _saveKeyword(keyword);
    }
    if (mounted) {
      Navigator.pop(
        context,
        CommunityFilterResult(
          keyword: keyword,
          onlyVerified: _onlyVerified,
          selectedCategories: _selectedCategories,
          selectedCountries: _selectedCountries,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── 상단 검색바 ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.black12)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: '궁금한 장소나 정보를 찾아보세요.',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _apply(),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _apply,
                    child: const Icon(Icons.search, size: 28),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 최근 검색어 ───────────────────────────────────
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '최근 검색어',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        if (_recentKeywords.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('최근 검색어 삭제'),
                                  content: const Text('모든 최근 검색어를 삭제하시겠습니까?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('취소'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _clearAllKeywords();
                                      },
                                      child: const Text('삭제', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline, size: 20, color: Colors.black54),
                                const SizedBox(width: 4),
                                Text(
                                  '전체 삭제',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 최근 검색어 목록
                    if (_recentKeywords.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '최근 검색어가 없습니다.',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _recentKeywords
                            .map((kw) => _recentKeywordChip(kw))
                            .toList(),
                      ),

                    const SizedBox(height: 32),
                    const Text('필터', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),

                    const SizedBox(height: 16),
                    const Text('사용자', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _userFilterButton('전체 사용자', !_onlyVerified, () => setState(() => _onlyVerified = false))),
                        const SizedBox(width: 12),
                        Expanded(child: _userFilterButton('인증된 사용자', _onlyVerified, () => setState(() => _onlyVerified = true))),
                      ],
                    ),

                    const SizedBox(height: 32),
                    const Text('카테고리', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: _categoryWithIcon.entries.map((e) {
                        final isSelected = _selectedCategories.contains(e.key);
                        return _filterChip(
                          label: e.key,
                          iconText: e.value,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) _selectedCategories.remove(e.key);
                              else _selectedCategories.add(e.key);
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),
                    const Text('나라 (선택)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: _countries.map((c) {
                        final isSelected = _selectedCountries.contains(c);
                        return _filterChip(
                          label: c,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) _selectedCountries.remove(c);
                              else _selectedCountries.add(c);
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _apply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD54F),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('적용하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 최근 검색어 칩 (탭: 자동 입력, X 버튼: 개별 삭제) ─────
  Widget _recentKeywordChip(String text) {
    return GestureDetector(
      onTap: () => _onRecentKeywordTap(text),
      child: Container(
        padding: const EdgeInsets.only(left: 14, right: 6, top: 8, bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _removeKeyword(text),
              child: Icon(Icons.close, size: 15, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userFilterButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          border: Border.all(color: isSelected ? Colors.black : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              label.contains('인증') ? Icons.check_circle : Icons.person_outline,
              size: 20,
              color: isSelected ? Colors.white : Colors.black45,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    String? iconText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD54F) : Colors.white,
          border: Border.all(color: isSelected ? const Color(0xFFFFD54F) : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(22),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconText != null) ...[
              Text(iconText, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
