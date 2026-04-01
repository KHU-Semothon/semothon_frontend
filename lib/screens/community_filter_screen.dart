import 'package:flutter/material.dart';

class CommunityFilterResult {
  final Set<String> selectedCategories;
  final Set<String> selectedCountries;

  const CommunityFilterResult({
    required this.selectedCategories,
    required this.selectedCountries,
  });
}

class CommunityFilterScreen extends StatefulWidget {
  final Set<String> initialCategories;
  final Set<String> initialCountries;

  const CommunityFilterScreen({
    super.key,
    required this.initialCategories,
    required this.initialCountries,
  });

  @override
  State<CommunityFilterScreen> createState() => _CommunityFilterScreenState();
}

class _CommunityFilterScreenState extends State<CommunityFilterScreen> {
  static const List<String> _categories = ['식당', '화장실', '쇼핑', '유적'];
  static const List<String> _countries  = ['일본', '중국', '미국', '영국'];

  late Set<String> _selectedCategories;
  late Set<String> _selectedCountries;

  @override
  void initState() {
    super.initState();
    _selectedCategories = Set.from(widget.initialCategories);
    _selectedCountries  = Set.from(widget.initialCountries);
  }

  void _toggleCategory(String value) {
    setState(() {
      if (_selectedCategories.contains(value)) {
        _selectedCategories.remove(value);
      } else {
        _selectedCategories.add(value);
      }
    });
  }

  void _toggleCountry(String value) {
    setState(() {
      if (_selectedCountries.contains(value)) {
        _selectedCountries.remove(value);
      } else {
        _selectedCountries.add(value);
      }
    });
  }

  void _reset() {
    setState(() {
      _selectedCategories.clear();
      _selectedCountries.clear();
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      CommunityFilterResult(
        selectedCategories: Set.from(_selectedCategories),
        selectedCountries:  Set.from(_selectedCountries),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '검색 필터',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 카테고리 섹션 ─────────────────────────────
                  const Text(
                    '카테고리',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildGrid(_categories, _selectedCategories, _toggleCategory),

                  const SizedBox(height: 32),

                  // ── 나라 선택 섹션 ────────────────────────────
                  const Text(
                    '나라 선택',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildGrid(_countries, _selectedCountries, _toggleCountry),
                ],
              ),
            ),
          ),

          // ── 하단 버튼 ─────────────────────────────────────────
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Row(
              children: [
                // 초기화
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDDDDDD)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: const Color(0xFFF5F5F5),
                    ),
                    child: const Text(
                      '초기화',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 적용
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text(
                      '적용',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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

  /// items를 2열 그리드로 체크박스와 함께 렌더링합니다.
  Widget _buildGrid(
    List<String> items,
    Set<String> selected,
    void Function(String) onToggle,
  ) {
    // items를 2열로 배치
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: _checkItem(items[i], selected.contains(items[i]), onToggle)),
            if (i + 1 < items.length)
              Expanded(child: _checkItem(items[i + 1], selected.contains(items[i + 1]), onToggle))
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      );
      rows.add(const SizedBox(height: 14));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _checkItem(String label, bool isSelected, void Function(String) onToggle) {
    return GestureDetector(
      onTap: () => onToggle(label),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.black : const Color(0xFFCCCCCC),
                width: 1.5,
              ),
              color: isSelected ? Colors.black : Colors.white,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? Colors.black : const Color(0xFF555555),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
