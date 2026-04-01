import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _isLoading = true;
  String _nickname = '';
  int _trustScore = 0;
  List<dynamic> _travelExperiences = [];

  @override
  void initState() {
    super.initState();
    _fetchMyProfile();
  }

  Future<void> _fetchMyProfile() async {
    try {
      final profileData = await ApiService().getMyProfile();
      if (mounted) {
        setState(() {
          _nickname = profileData['nickname'] ?? '이름 없음';
          _trustScore = profileData['trustScore'] ?? 0;
          _travelExperiences = profileData['travelExperiences'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // 에러 상황을 다루기 위한 간단한 안내
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 정보를 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('마이페이지'),
        centerTitle: false,
        backgroundColor: const Color(0xFFF5F5F5),
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE0E0E0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, size: 40, color: Colors.grey),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nickname.isEmpty ? '알 수 없음' : _nickname,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '신뢰 점수: $_trustScore',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Travel Experiences Section
                    if (_travelExperiences.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          '여행 경험',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _travelExperiences.length,
                        itemBuilder: (context, index) {
                          final exp = _travelExperiences[index];
                          final country = exp['country'] ?? '알 수 없는 국가';
                          final visitCount = exp['visitCount'] ?? 0;
                          final stayMonths = exp['stayMonths'] ?? 0;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.flight_takeoff, color: Colors.blueAccent),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        country,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '총 $visitCount회 방문 • $stayMonths개월 체류',
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Progress Bar Section (Trust Score Gauge)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('신뢰도 게이지',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.grey.shade300,
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (_trustScore / 1000).clamp(0.0, 1.0), // 예: 만점 1000점 기준
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: const LinearGradient(
                                    colors: [Colors.pinkAccent, Colors.blueAccent],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned(
                                      right: -10, // 게이지 끝 뱃지 위치
                                      top: -4,
                                      bottom: -4,
                                      child: Container(
                                        width: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.blueAccent, width: 2),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),

                    // Menu Sections
                    _buildMenuItem('인증'),
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),
                    _buildMenuItem('이용 안내'),
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),
                    const SizedBox(height: 16), // space between sections
                    
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),
                    _buildMenuItem('각종 설정'),
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),
                    _buildMenuItem('알림'),
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),
                    _buildMenuItem('고객센터'),
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),

                    const SizedBox(height: 16),
                    // 로그아웃 (테스트용)
                    Container(
                      color: Colors.white,
                      child: ListTile(
                        title: const Text(
                          '로그아웃',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () async {
                          // 토큰 삭제 후 첫 화면 등으로 분기 처리하실 수 있습니다.
                          await ApiService().logout();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('로그아웃 되었습니다.')));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMenuItem(String title) {
    return Container(
      color: Colors.white,
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {},
      ),
    );
  }
}
