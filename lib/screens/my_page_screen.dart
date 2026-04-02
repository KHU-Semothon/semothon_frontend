import 'dart:io';
import 'package:flutter/material.dart';
import 'travel_experience_screen.dart';
import '../services/api_service.dart';
import 'sign_in_screen.dart';
import 'profile_edit_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final ApiService _api = ApiService();

  // 프로필 상태 관리
  Color _authMarkColor = const Color(0xFF29B6F6);
  bool _isAuthMarkVisible = true;
  int _livingYears = 2;
  int _visitCount = 5;
  String _nickname = '';
  String _avatarUrl = '';
  File? _avatarFile;
  double _trustLevel = 0.0;
  bool _isProfileLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ── 서버에서 프로필 로드 ──────────────────────────────
  Future<void> _loadProfile() async {
    setState(() => _isProfileLoading = true);
    try {
      final data = await _api.getMyProfile();
      if (mounted) {
        setState(() {
          // API 명세서 camelCase 키 기준
          // nickname (회원가입 파라미터) > username (게시글 응답 키) 순으로 시도
          _nickname    = data['nickname']     as String? ??
                         data['username']     as String? ?? '';
          // profileImage (REST 관례)
          _avatarUrl   = data['profileImage'] as String? ?? '';
          // trustScore: 0~100 정수 값 (명세서 패턴 기반)
          _trustLevel  = (data['trustScore']  as num?)?.toDouble() ?? 0.0;
          if (_trustLevel > 1) _trustLevel /= 100; // 0~100이면 0~1로 변환
          // 거주/방문 정보
          _livingYears = (data['livingYears'] as num?)?.toInt() ?? _livingYears;
          _visitCount  = (data['visitCount']  as num?)?.toInt() ?? _visitCount;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _nickname = _nickname.isEmpty ? '' : _nickname);
    } finally {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  final List<Color> _rainbowColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    const Color(0xFF4B0082), // Indigo
    const Color(0xFF8B00FF), // Violet
  ];

  // 인증 마크 색상 선택 팝업
  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('인증 마크 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _rainbowColors.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _authMarkColor = _rainbowColors[index];
                        _isAuthMarkVisible = true;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _rainbowColors[index],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (_isAuthMarkVisible && _authMarkColor == _rainbowColors[index]) ? Colors.black : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() => _isAuthMarkVisible = false);
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('인증마크 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 거주/방문 횟수 선택 바텀시트
  void _showExperiencePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('경험 정보 수정', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNumberPicker('거주 기간 (년)', _livingYears, (val) {
                  setState(() => _livingYears = val);
                }),
                _buildNumberPicker('방문 횟수 (회)', _visitCount, (val) {
                  setState(() => _visitCount = val);
                }),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('확인', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPicker(String label, int currentVal, Function(int) onUpdate) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Row(
          children: [
            IconButton(onPressed: () => onUpdate(currentVal > 0 ? currentVal - 1 : 0), icon: const Icon(Icons.remove_circle_outline)),
            Text('$currentVal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(onPressed: () => onUpdate(currentVal + 1), icon: const Icon(Icons.add_circle_outline)),
          ],
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiService().logout();
      if (!mounted) return;
      // 로그인 화면으로 이동 (돌아가기 불가능하게 교체)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
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
        centerTitle: true,
        title: const Text(
          '마이페이지',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          if (!_isProfileLoading)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black54, size: 20),
              tooltip: '새로고침',
              onPressed: _loadProfile,
            ),
        ],
      ),
      body: _isProfileLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. 프로필 영역 ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFFD0D0D0),
                        backgroundImage: _avatarFile != null
                            ? FileImage(_avatarFile!) as ImageProvider
                            : (_avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null),
                        child: (_avatarFile == null && _avatarUrl.isEmpty)
                            ? const Icon(Icons.person, size: 36, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF29B6F6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _nickname,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            // 인증 마크 (커스텀 색상 및 터치 인터랙션)
                            GestureDetector(
                              onTap: _showColorPicker,
                              child: _isAuthMarkVisible 
                                ? Icon(
                                    Icons.verified,
                                    size: 18,
                                    color: _authMarkColor,
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.add, size: 10, color: Colors.grey),
                                        SizedBox(width: 2),
                                        Text('인증마크', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 여행/방문 횟수 선택 (인터랙션 추가)
                        GestureDetector(
                          onTap: _showExperiencePicker,
                          child: Text(
                            '일본 거주 $_livingYears년 · 방문 $_visitCount회',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 2. 신뢰도 바 ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('😊', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '신뢰도 ${(_trustLevel * 100).toInt()}%',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '앙금류 사용자',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (ctx, constraints) {
                    final total = constraints.maxWidth;
                    final filled = total * _trustLevel;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 배경 바
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // 채워진 바
                        Container(
                          height: 6,
                          width: filled,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5A5F),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // 핸들 점
                        Positioned(
                          left: filled - 10,
                          top: -7,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFF29B6F6),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 3. 프로필 편집 / 여행 경험 관리 버튼 ──────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final result = await Navigator.push<ProfileEditResult>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileEditScreen(
                              currentNickname: _nickname,
                              currentAvatarFile: _avatarFile,
                            ),
                          ),
                        );
                        if (result != null && mounted) {
                          setState(() {
                            _nickname = result.nickname;
                            _avatarFile = result.avatarFile;
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFDDDDDD)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        '프로필 편집',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // 여행 경험 관리 화면으로 이동
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TravelExperienceScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFDDDDDD)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        '여행 경험 관리',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFF0F0F0), thickness: 8),

            // ── 4. 메뉴 그룹 1: 활동 ───────────────────────────
            _buildMenuItem('내가 쓴 글'),
            _buildMenuItem('내가 단 댓글'),
            _buildMenuItem('좋아요'),

            const Divider(height: 1, color: Color(0xFFF0F0F0), thickness: 8),

            // ── 5. 메뉴 그룹 2: 인증 ───────────────────────────
            _buildMenuItem('인증 상태'),

            const Divider(height: 1, color: Color(0xFFF0F0F0), thickness: 8),

            // ── 6. 메뉴 그룹 3: 설정 ───────────────────────────
            _buildMenuItem('알림 설정'),
            _buildMenuItem('계정 설정'),

            const Divider(height: 1, color: Color(0xFFF0F0F0), thickness: 8),

            // ── 7. 메뉴 그룹 4: 지원 ───────────────────────────
            _buildMenuItem('고객센터'),
            _buildMenuItem('신고 내역'),

            const Divider(height: 1, color: Color(0xFFF0F0F0), thickness: 8),

            // ── 8. 로그아웃 ─────────────────────────────────────
            InkWell(
              onTap: _handleLogout,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('로그아웃', style: TextStyle(fontSize: 15, color: Colors.red, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 15)),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
