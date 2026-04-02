import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:image_picker/image_picker.dart';
import '../models/community_post.dart';
import '../services/api_service.dart';
import 'location_picker_screen.dart';

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
  String _location = '일본 도쿄도 시부야구 도겐자카 2-2-1';
  NLatLng? _pickedLatLng;
  bool _isPosting = false;

  // 멀티미디어
  final List<File> _selectedImages = [];
  File? _selectedVideo;
  final ImagePicker _picker = ImagePicker();

  static const List<String> _categories = ['주의', '문화', '맛집', '카페', '기타'];

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

  Future<void> _submit() async {
    if (!_canPost) return;
    setState(() => _isPosting = true);

    final now = DateTime.now();
    final newPost = CommunityPost(
      id: now.millisecondsSinceEpoch.toString(),
      username: '나',
      isVerified: false,
      title: _titleController.text.trim(),
      preview: _bodyController.text.trim(),
      timeAgo: '방금',
      likes: 0,
      comments: 0,
      bookmarks: 0,
      hasThumbnail: false,
      category: _selectedCategory!,
      country: '일본',
      createdAt: now,
      latitude: _pickedLatLng?.latitude,
      longitude: _pickedLatLng?.longitude,
      address: _location,
    );

    // 서버 전송 (실패해도 로컬에선 게시글 반환)
    try {
      await _api.createPost(newPost);
    } catch (_) {
      // 서버 오류 시 경고만 표시, 화면은 정상 종료
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버 저장에 실패했지만 로컬에 반영했습니다.')),
        );
      }
    }

    if (mounted) {
      setState(() => _isPosting = false);
      Navigator.pop(context, newPost); // 항상 반환
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
          // 최대 10장
          final remaining = 10 - _selectedImages.length;
          final toAdd = picked.take(remaining).map((x) => File(x.path)).toList();
          _selectedImages.addAll(toAdd);
          if (picked.length > remaining) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('사진은 최대 10장까지 쳊부할 수 있습니다.')),
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
              // TODO: 임시저장 기능
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
                    onTap: _canPost ? _submit : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _canPost ? Colors.black : Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '완료',
                        style: TextStyle(
                          color: _canPost ? Colors.white : Colors.grey[500],
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

                    // ── 카테고리 ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: const Text(
                        '카테고리',
                        style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        children: _categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = isSelected ? null : cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.black : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? Colors.black : const Color(0xFFDDDDDD),
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.white : Colors.black,
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
                        minLines: 12,
                        decoration: const InputDecoration(
                          hintText: '자유롭게 경험을 공유하거나 궁금한 점을 남겨보세요.',
                          hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB), height: 1.6),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    // ── 선택된 사진/동영상 마리보기 ────────────────
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
                            // 동영상 아이템
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
                            // 사진 아이템
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
                // 위치 행
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 18, color: Colors.black54),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _location,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: _changeLocation,
                      child: const Text(
                        '위치 변경',
                        style: TextStyle(fontSize: 12, color: Colors.black54, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 미디어 버튼 행
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
          // 하단 바 높이 확보 (키보드 올라올 때)
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 8),
        ],
      ),
    );
  }

  // ── 미디어 미리보기 타일 ───────────────────────────────
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

  // ── 미디어 버튼 (사진/동영상) ────────────────────────────
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
