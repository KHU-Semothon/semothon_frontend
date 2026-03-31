import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'main_scaffold.dart';
import 'sign_up_screen.dart';
import '../widgets/social_login_button.dart'; // 기존의 소셜 로그인 버튼 재사용

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 이미지의 배경색에 가까운 부드러운 민트색/하늘색
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFBAE5E5), Color(0xFF8DCFD1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2), // 위쪽 여백
                // 이메일 입력 필드
                TextField(
                  decoration: InputDecoration(
                    hintText: 'email@domain.com',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 패스워드 입력 필드
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'password',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 로그인 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const MainScaffold()),
                      );
                    },
                    child: const Text(
                      '로그인',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // 구분선은 없고 바로 소셜 로그인
                SocialLoginButton(
                  text: 'Google 계정으로 계속하기',
                  icon: Icons.g_mobiledata_rounded,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MainScaffold()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SocialLoginButton(
                  text: 'Apple 계정으로 계속하기',
                  icon: Icons.apple,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MainScaffold()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // 계정 만들기 링크
                RichText(
                  text: TextSpan(
                    text: '계정이 없으신가요? ',
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                    children: [
                      TextSpan(
                        text: '계정만들기',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = () {
                          // 계정 만들기 화면(SignUpScreen)으로 이동
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignUpScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 3), // 아래쪽 여백
              ],
            ),
          ),
        ),
      ),
    );
  }
}
