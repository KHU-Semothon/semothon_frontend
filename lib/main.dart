import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'screens/main_scaffold.dart';
import 'screens/sign_in_screen.dart';
import 'services/api_service.dart';
import 'services/user_profile_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 저장된 프로필 정보 복원
  await UserProfileService().load();

  try {
    // 네이버 지도 SDK 초기화 
    await FlutterNaverMap().init(
      clientId: '2qzwglommb',
      onAuthFailed: (error) {
        debugPrint('네이버 지도 인증 실패: $error');
      },
    );
  } catch (e) {
    debugPrint('네이버 지도 SDK 초기화 중 에러 발생: $e');
  }

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Semothon App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        primaryColor: Colors.black,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.grey,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F5F5),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black, 
            fontSize: 18, 
            fontWeight: FontWeight.bold
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
        ),
        useMaterial3: true,
      ),
      home: const SplashRouter(),
    );
  }
}

/// 앱 시작 시 로그인 여부에 따라 라우팅
class SplashRouter extends StatelessWidget {
  const SplashRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ApiService().isLoggedIn(),
      builder: (context, snapshot) {
        // 로딩 중
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
          );
        }
        // 로그인 상태면 메인으로
        if (snapshot.data == true) {
          return const MainScaffold();
        }
        // 비로그인이면 로그인 화면
        return const SignInScreen();
      },
    );
  }
}
