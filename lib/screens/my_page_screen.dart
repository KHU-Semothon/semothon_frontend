import 'package:flutter/material.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '마이페이지',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none, color: Colors.grey)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined, color: Colors.grey)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. 프로필 영역
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Color(0xFFE0E0E0),
                        // backgroundImage: NetworkImage('유저이미지주소'),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF),
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
                        const Text(
                          'emberecho',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text('ㄹㄹㄹㄹ', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildProfileBadge('거주 기간'),
                            _buildProfileBadge('방문횟수'),
                            _buildProfileBadge('인증여부'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. 신뢰도 슬라이더/프로그레스 바
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Container(
                        height: 6,
                        width: MediaQuery.of(context).size.width * 0.7, // 신뢰도 수치에 따른 비중
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5A5F), // 시안의 붉은 계열 색상
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.7 - 10,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFF80D8FF), // 하늘색 핸들
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. 인증/활동 기록 탭 바
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    indicatorColor: Colors.black,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: '인증'),
                      Tab(text: '활동 기록'),
                    ],
                  ),
                  // 실제 데이터 리스트가 들어갈 자리 (TabBarView)
                  Container(
                    height: 1,
                    color: Colors.grey[300],
                  ),
                ],
              ),
            ),

            // 4. 하단 메뉴 리스트
            const SizedBox(height: 20),
            _buildMenuItem('신고 등등'),
            _buildMenuItem('각종 설정'),
            _buildMenuItem('알림이나'),
            _buildMenuItem('고객센터 그런거'),
          ],
        ),
      ),
      // 하단 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: '채팅',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '마이페이지',
          ),
        ],
      ),
    );
  }

  Widget _buildProfileBadge(String label) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFE0E0E0),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMenuItem(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
