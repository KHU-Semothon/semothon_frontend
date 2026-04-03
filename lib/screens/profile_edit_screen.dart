import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/user_avatar.dart';

/// 프로필 편집 결과 데이터
class ProfileEditResult {
  final String nickname;
  final File? avatarFile; // null이면 기본 프로필
  final bool useDefault;

  const ProfileEditResult({
    required this.nickname,
    this.avatarFile,
    this.useDefault = true,
  });
}

// ─────────────────────────────────────────────────────────────
// 프로필 편집 화면
// ─────────────────────────────────────────────────────────────
class ProfileEditScreen extends StatefulWidget {
  final String currentNickname;
  final File? currentAvatarFile;

  const ProfileEditScreen({
    super.key,
    required this.currentNickname,
    this.currentAvatarFile,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _nicknameController;
  File? _selectedImage;
  bool _useDefault = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.currentNickname);
    // 현재 전역 서비스 상태를 초기값으로
    final svc = UserProfileService();
    _useDefault    = svc.useDefault;
    _selectedImage = svc.avatarFile;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  // ── 프로필 사진 선택 다이얼로그 ─────────────────────────────
  void _showAvatarChoiceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '프로필 사진 변경',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            // 기본 프로필 미리보기
            CircleAvatar(
              radius: 40,
              backgroundImage: const AssetImage('assets/images/default_profile.png'),
              backgroundColor: const Color(0xFFD0D0D0),
            ),
            const SizedBox(height: 16),
            // 기본 프로필 버튼
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _useDefault    = true;
                    _selectedImage = null;
                  });
                },
                icon: const Icon(Icons.face, size: 18),
                label: const Text('기본 프로필로 설정'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Color(0xFFDDDDDD)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 갤러리 선택 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showImageSourceSheet();
                },
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('사진 첨부'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 이미지 선택 소스 바텀시트 ─────────────────────────────────
  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() {
          _selectedImage = File(picked.path);
          _useDefault    = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지를 가져올 수 없습니다: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 전역 프로필 서비스 업데이트 (즉시 반영)
      final svc = UserProfileService();
      await svc.setNickname(nickname);
      if (_useDefault) {
        await svc.setDefaultAvatar();
      } else if (_selectedImage != null) {
        await svc.setAvatarFile(_selectedImage!);
      }

      // 서버에도 저장 시도 (실패 무시)
      try {
        final api = ApiService();
        await api.updateProfile(
          nickname: nickname,
          avatarPath: (!_useDefault && _selectedImage != null) ? _selectedImage!.path : null,
        );
      } catch (e) {
        debugPrint('[ProfileEdit] 서버 저장 실패 (로컬 적용됨): $e');
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      Navigator.pop(
        context,
        ProfileEditResult(
          nickname: nickname,
          avatarFile: _useDefault ? null : _selectedImage,
          useDefault: _useDefault,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 저장 실패: $e')),
      );
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
          '프로필 편집',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isSaving
                ? const Center(
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : TextButton(
                    onPressed: _save,
                    child: const Text(
                      '저장',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 36),

            // ── 프로필 사진 ─────────────────────────────────────────
            GestureDetector(
              onTap: _showAvatarChoiceDialog,
              child: Stack(
                children: [
                  // 아바타 (기본 or 선택한 사진)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD0D0D0),
                      image: DecorationImage(
                        image: (!_useDefault && _selectedImage != null)
                            ? FileImage(_selectedImage!) as ImageProvider
                            : const AssetImage('assets/images/default_profile.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // 카메라 아이콘 배지
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showAvatarChoiceDialog,
              child: Text(
                _useDefault ? '기본 프로필 사용 중  ·  탭하여 변경' : '사용자 지정 사진  ·  탭하여 변경',
                style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
              ),
            ),

            const SizedBox(height: 36),

            // ── 닉네임 입력 ─────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '닉네임',
                style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nicknameController,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              maxLength: 20,
              decoration: InputDecoration(
                hintText: '닉네임을 입력하세요',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFFF7F7F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                ),
                suffixIcon: _nicknameController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () => setState(() => _nicknameController.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 32),

            // ── 저장 버튼 ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('저장하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
