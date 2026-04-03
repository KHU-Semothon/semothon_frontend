import 'package:flutter/material.dart';
import 'map_home_screen.dart';
import 'qa_screen.dart';
import 'save_screen.dart';
import 'my_page_screen.dart';
import 'sign_in_screen.dart';

class MainScaffold extends StatefulWidget {
  final bool isGuest;
  const MainScaffold({super.key, this.isGuest = false});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  // 비로그인 시 접근 제한이 필요한 탭 인덱스
  static const Set<int> _guardedTabs = {2, 3}; // 폴더, 마이페이지

  final List<Widget> _screens = [
    const MapHomeScreen(),
    const QaScreen(),
    const SaveScreen(),
    const MyPageScreen(),
  ];

  void _onTabTap(int index) {
    // 비로그인 상태에서 보호된 탭 진입 시 로그인 화면으로 이동
    if (widget.isGuest && _guardedTabs.contains(index)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: _onTabTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Q&A',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: '저장',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '마이',
          ),
        ],
      ),
    );
  }
}
