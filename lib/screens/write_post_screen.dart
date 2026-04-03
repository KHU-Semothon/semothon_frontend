import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:image_picker/image_picker.dart';
import '../models/community_post.dart';
import '../services/api_service.dart';
import 'location_picker_screen.dart';
import 'sign_in_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ──────────────────────────────────────────────
// 글쓰기 화면
// ──────────────────────────────────────────────
class WritePostScreen extends StatefulWidget {
  const WritePostScreen({super.key});

  @override
  State<WritePostScreen> createState() => _WritePostScreenState();
}

class _WritePostScreenState extends State<WritePostScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _bodyFocusNode = FocusNode();

  String? _selectedCategory;
  String? _selectedCountry;
  String _location = '위치를 선택해주세요';
  NLatLng? _pickedLatLng;
  bool _isPosting = false;

  // 멀티미디어
  final List<File> _selectedImages = [];
  File? _selectedVideo;
  final ImagePicker _picker = ImagePicker();

  // 필터 화면과 동일한 카테고리/나라
  static const Map<String, String> _categoryWithIcon = {
    '위험/주의': '⚠️',
    '문화': '🎎',
    '맛집/물가': '🍽️',
    '카페': '☕',
    '꿀팁': '📍',
    '기타': '☁️',
  };

  static const List<String> _countries = ['일본', '베트남', '태국', '대만', '한국', '유럽', '미국'];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  bool get _canPost =>
      _titleController.text.trim().isNotEmpty &&
      _bodyController.text.trim().isNotEmpty &&
      _selectedCategory != null;
      // 위치/나라는 선택 사항

  Future<void> _submit() async {
    if (_isPosting) return;
    setState(() => _isPosting = true);

    try {
      // 1. 로그인 여부 최종 확인 (최우선)
      final isLoggedIn = await _api.isLoggedIn();
      if (!isLoggedIn && mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다. 로그인 화면으로 이동합니다.')),
        );
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen()));
        return;
      }

      // 2. 입력값 검증
      if (!_canPost) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 항목(제목, 내용, 카테고리, 나라)을 입력해주세요.')),
        );
        return;
      }

      // 3. 미디어 업로드 (있을 경우)
      List<String> mediaUrls = [];
      final List<String> localPaths = _selectedImages.map((f) => f.path).toList();
      if (_selectedVideo != null) localPaths.add(_selectedVideo!.path);

      if (localPaths.isNotEmpty) {
        mediaUrls = await _api.uploadMedia(localPaths);
      }

      // 4. 카테고리 → 서버 Enum 변환
      String mappedCategory = 'ETC';
      switch (_selectedCategory) {
        case '위험/주의': mappedCategory = 'DANGER'; break;
        case '문화':     mappedCategory = 'CULTURE'; break;
        case '맛집/물가': mappedCategory = 'PRICE'; break;
        case '카페':     mappedCategory = 'PRICE'; break;
        case '꿀팁':     mappedCategory = 'ETC'; break;
        case '기타':     mappedCategory = 'ETC'; break;
      }

      // 5. 질문 등록
      // 위치 미설정 시 null 전달 (기본 텍스트는 서버에 보내지 않음)
      final String? locationToSend = (_location == '위치를 선택해주세요' || _location.isEmpty)
          ? null
          : _location;

      final newId = await _api.createQuestion(
        title: _titleController.text.trim(),
        content: _bodyController.text.trim(),
        category: mappedCategory,
        locationKeyword: locationToSend,
        country: _selectedCountry,
        mediaUrls: mediaUrls,
      );

      // 위치 정보가 있으면 SharedPreferences에 저장 (서버 목록 API가 반환하지 않으므로)
      if (locationToSend != null && locationToSend.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        if (newId != null) {
          // 서버에서 ID를 받은 경우: 정식 키로 저장
          await prefs.setString('location_$newId', locationToSend);
          debugPrint('[WritePost] 위치 저장: location_$newId = $locationToSend');
        } else {
          // 서버가 ID를 반환하지 않은 경우: 제목 기반 임시 키로 저장 (목록 조회 시 제목 매칭)
          final titleKey = _titleController.text.trim().hashCode.toString();
          await prefs.setString('location_title_$titleKey', locationToSend);
          debugPrint('[WritePost] 위치 임시 저장 (ID 없음): location_title_$titleKey = $locationToSend');
        }
      }

      if (mounted) {
        setState(() => _isPosting = false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('[WritePost] 등록 실패 상세: $e');
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('등록 실패: $e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '확인',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  void _changeLocation() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialPosition: _pickedLatLng),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _pickedLatLng = result.position;
        _location = result.address;
      });
    }
  }

  // ── 사진 선택 (다중) ───────────────────────────
  Future<void> _pickImages() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (picked.isNotEmpty && mounted) {
        setState(() {
          final remaining = 10 - _selectedImages.length;
          final toAdd = picked.take(remaining).map((x) => File(x.path)).toList();
          _selectedImages.addAll(toAdd);
          if (picked.length > remaining) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('사진은 최대 10장까지 첨부할 수 있습니다.')),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진을 가져올 수 없습니다: $e')),
        );
      }
    }
  }

  // ── 동영상 선택 ───────────────────────────────
  Future<void> _pickVideo() async {
    try {
      final XFile? picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked != null && mounted) {
        setState(() => _selectedVideo = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('동영상을 가져올 수 없습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          '글 쓰기',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('임시저장 되었습니다.')),
              );
            },
            child: Text('임시저장', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isPosting
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : GestureDetector(
                    onTap: _submit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _canPost ? Colors.black : Colors.grey[400],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '완료',
                        style: TextStyle(
                          color: _canPost ? Colors.white : Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).requestFocus(_bodyFocusNode),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 제목 입력 ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: TextField(
                        controller: _titleController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          hintText: '제목을 입력해주세요.',
                          hintStyle: TextStyle(fontSize: 17, color: Color(0xFFBBBBBB), fontWeight: FontWeight.w600),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE), indent: 16, endIndent: 16),

                    // ── 카테고리 ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: const Text(
                        '카테고리',
                        style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categoryWithIcon.entries.map((e) {
                          final isSelected = _selectedCategory == e.key;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = isSelected ? null : e.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFD54F) : Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFFFD54F) : const Color(0xFFDDDDDD),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(e.value, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(
                                    e.key,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE), indent: 16, endIndent: 16),

                    // ── 나라 (선택) ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: const Text(
                        '나라 (선택)',
                        style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _countries.map((country) {
                          final isSelected = _selectedCountry == country;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCountry = isSelected ? null : country),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFD54F) : Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFFFD54F) : const Color(0xFFDDDDDD),
                                ),
                              ),
                              child: Text(
                                country,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 4),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE), indent: 16, endIndent: 16),

                    // ── 본문 입력 ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextField(
                        controller: _bodyController,
                        focusNode: _bodyFocusNode,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.6),
                        maxLines: null,
                        minLines: 10,
                        decoration: const InputDecoration(
                          hintText: '자유롭게 경험을 공유하거나 궁금한 점을 남겨보세요.',
                          hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB), height: 1.6),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    // ── 선택된 사진/동영상 미리보기 ────────────────
                    if (_selectedImages.isNotEmpty || _selectedVideo != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemCount: _selectedImages.length + (_selectedVideo != null ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (_selectedVideo != null && i == _selectedImages.length) {
                              return _mediaPreviewTile(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(_selectedVideo!, fit: BoxFit.cover),
                                    const Center(
                                      child: Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                                    ),
                                  ],
                                ),
                                onRemove: () => setState(() => _selectedVideo = null),
                              );
                            }
                            return _mediaPreviewTile(
                              child: Image.file(_selectedImages[i], fit: BoxFit.cover),
                              onRemove: () => setState(() => _selectedImages.removeAt(i)),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── 하단 위치 / 미디어 바 ──────────────────────────
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _changeLocation,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Color(0xFFFFB74D)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _location == '위치를 선택해주세요' 
                              ? '위치를 설정해주세요' 
                              : (_selectedCountry != null ? '$_selectedCountry · $_location' : _location),
                          style: TextStyle(
                            fontSize: 13, 
                            color: _location == '위치를 선택해주세요' ? Colors.grey : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _mediaButton(Icons.image_outlined, '사진', _pickImages),
                    const SizedBox(width: 16),
                    _mediaButton(
                      Icons.play_circle_outline,
                      '동영상',
                      _selectedVideo != null
                          ? () => setState(() => _selectedVideo = null)
                          : _pickVideo,
                    ),
                    if (_selectedVideo != null) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle, size: 14, color: Colors.green),
                      const SizedBox(width: 2),
                      const Text('동영상 선택됨', style: TextStyle(fontSize: 11, color: Colors.green)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 8),
        ],
      ),
    );
  }

  Widget _mediaPreviewTile({required Widget child, required VoidCallback onRemove}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 100,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black54),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ],
      ),
    );
  }
}
