import 'dart:io';
import 'package:flutter/material.dart';
import 'travel_experience_screen.dart';
import '../services/api_service.dart';
import '../services/user_profile_service.dart';
import 'sign_in_screen.dart';
import 'profile_edit_screen.dart';
import 'my_activity_screen.dart';

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

    // 먼저 로컬에 저장된 프로필 상태 복원
    final svc = UserProfileService();
    if (svc.nickname.isNotEmpty) {
      _nickname = svc.nickname;
    }
    _avatarFile = svc.avatarFile;

    try {
      final data = await _api.getMyProfile();
      if (mounted) {
        setState(() {
          // API 명세서 camelCase 키 기준
          // nickname (회원가입 파라미터) > username (게시글 응답 키) 순으로 시도
          final serverNickname = data['nickname'] as String? ??
                                 data['username'] as String? ?? '';
          if (serverNickname.isNotEmpty) {
            _nickname = serverNickname;
            // 서버 닉네임도 서비스에 동기화
            svc.setNickname(serverNickname);
          }
          // profileImage (REST 관례)
          _avatarUrl   = data['profileImage'] as String? ?? '';
          // trustScore: 0~100 정수 값 (명세서 패턴 기반, 서버 기본값 90%)
          _trustLevel  = (data['trustScore']  as num?)?.toDouble() ?? 90.0;
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
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('인증 마크 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _rainbowColors.map((color) {
                  final isSelected = _isAuthMarkVisible && _authMarkColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _authMarkColor = color;
                        _isAuthMarkVisible = true;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: [
                          if (isSelected) BoxShadow(color: color.withAlpha(100), blurRadius: 8, spreadRadius: 1),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    setState(() => _isAuthMarkVisible = false);
                    Navigator.pop(ctx);
                  },
                  child: const Text('인증마크 제거', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
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
                        radius: 38,
                        backgroundColor: const Color(0xFFF5F5F5),
                        backgroundImage: _avatarFile != null
                            ? FileImage(_avatarFile!) as ImageProvider
                            : (_avatarUrl.isNotEmpty
                                ? NetworkImage(_avatarUrl)
                                : const AssetImage('assets/images/default_profile.png')),
                      ),
                      Positioned(
                        right: 0,
                        top: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF), // 밝은 하늘색
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
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
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            const SizedBox(width: 8),
                            // 인증 마크 (기능 유지)
                            if (_isAuthMarkVisible)
                            GestureDetector(
                              onTap: _showColorPicker,
                              child: Icon(
                                Icons.verified,
                                size: 20,
                                color: _authMarkColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '일본 거주 ${_livingYears}년 · 신뢰도 ${(_trustLevel * 100).toInt()}%',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
                      const Text('😊', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        '신뢰도 ${(_trustLevel * 100).toInt()}%',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '검증된 사용자',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (ctx, constraints) {
                    final total = constraints.maxWidth;
                    final filled = total * _trustLevel;
                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        // 배경 바
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // 채워진 바 (오렌지/옐로우)
                        Container(
                          height: 8,
                          width: filled,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA000),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // 핸들 점 (밝은 하늘색)
                        Positioned(
                          left: filled - 12,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00E5FF),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                )
                              ],
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
                    child: ElevatedButton(
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
                            _nickname   = result.nickname;
                            _avatarFile = result.avatarFile;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDE28A),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('프로필 편집', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TravelExperienceScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDE28A),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('여행 경험 관리', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFEEEEEE), thickness: 8), // 두꺼운 구분선

            // ── 4. 메뉴 그룹 1: 활동 ───────────────────────────
            _buildMenuItem('내가 쓴 글', type: ActivityType.myPosts),
            _buildMenuItem('내가 단 댓글', type: ActivityType.myComments),
            _buildMenuItem('좋아요', type: ActivityType.likedPosts),

            const Divider(height: 1, color: Color(0xFFEEEEEE), thickness: 8),

            // ── 5. 메뉴 그룹 2: 인증 ───────────────────────────
            _buildMenuItem('인증 상태'),

            const Divider(height: 1, color: Color(0xFFEEEEEE), thickness: 8),

            // ── 6. 메뉴 그룹 3: 설정 ───────────────────────────
            _buildMenuItem('알림 설정'),
            _buildMenuItem('계정 설정'),

            const Divider(height: 1, color: Color(0xFFEEEEEE), thickness: 8),

            // ── 7. 메뉴 그룹 4: 지원 ───────────────────────────
            _buildMenuItem('고객센터'),
            _buildMenuItem('신고 내역', type: ActivityType.reportedPosts),

            const Divider(height: 1, color: Color(0xFFEEEEEE), thickness: 8),

            // ── 8. 로그아웃 ─────────────────────────────────────
            _buildMenuItem('로그아웃', color: Colors.red, onTap: _handleLogout, icon: Icons.logout),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, {ActivityType? type, VoidCallback? onTap, Color? color, IconData? icon}) {
    return InkWell(
      onTap: () {
        if (onTap != null) {
          onTap();
        } else if (type != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => MyActivityScreen(type: type)));
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: color ?? Colors.black87),
                  const SizedBox(width: 12),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: color ?? Colors.black,
                    fontWeight: color != null ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const Spacer(),
                if (color == null)
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF5F5F5), indent: 20, endIndent: 20),
        ],
      ),
    );
  }
}
