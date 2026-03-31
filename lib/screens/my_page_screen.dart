import 'package:flutter/material.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

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
      body: SafeArea(
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
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(
                           '마이',
                           style: TextStyle(
                             fontSize: 20,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                         SizedBox(height: 4),
                         Text(
                           'ㅋㅋㅋㅋ',
                           style: TextStyle(
                             fontSize: 14,
                             color: Colors.grey,
                           ),
                         ),
                      ],
                    ),
                  ],
                ),
              ),

              // Progress Bar Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  height: 12,
                  width: double.infinity,
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
                        right: 80, // Example position
                        top: -4,
                        bottom: -4,
                        child: Container(
                          width: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blueAccent, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE0E0E0)),
              
              // Menu Sections
              _buildMenuItem('인증'),
              const Divider(height: 1, color: Color(0xFFE0E0E0)),
              _buildMenuItem('인증'),
              const Divider(height: 1, color: Color(0xFFE0E0E0)),
              
              const SizedBox(height: 16), // space between sections
              const Divider(height: 1, color: Color(0xFFE0E0E0)),
              _buildMenuItem('각종 설정'),
              const Divider(height: 1, color: Color(0xFFE0E0E0)),
              _buildMenuItem('알림이나'),
              const Divider(height: 1, color: Color(0xFFE0E0E0)),
              _buildMenuItem('고객센터 그런거'),
              const Divider(height: 1, color: Color(0xFFE0E0E0)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title) {
    return Container(
      color: Colors.white, // Setting menu items on white background to contrast the F5F5F5 scaffold
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
