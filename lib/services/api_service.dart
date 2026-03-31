import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

/// API 통신 중 발생하는 사용자 정의 예외 처리
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException({this.statusCode, required this.message});

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

/// Api 통신을 담당하는 메인 서비스 클래스
class ApiService {
  // 실제 서버의 baseUrl로 변경해야 합니다.
  static const String baseUrl = 'https://api.example.com';
  
  // 저장된 JWT 토큰을 가져오는 함수 (예: FlutterSecureStorage나 SharedPreferences 등을 통해 가져옴)
  Future<String?> _getToken() async {
    // TODO: 실제 토큰 저장소에서 토큰을 불러오는 로직으로 대체해야 합니다.
    return 'your_jwt_token_here';
  }

  /// 공통으로 API 응답을 처리하고 예외를 핸들링하는 내부 함수
  Future<Map<String, dynamic>> _callApi(
    String endpoint, {
    required String method,
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final Uri url = Uri.parse('$baseUrl$endpoint');
    final Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',
    };

    if (requiresAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    try {
      http.Response response;
      final encodedBody = body != null ? jsonEncode(body) : null;

      // 타임아웃 10초 적용
      const timeoutDuration = Duration(seconds: 10);

      switch (method) {
        case 'GET':
          response = await http.get(url, headers: headers).timeout(timeoutDuration);
          break;
        case 'POST':
          response = await http.post(url, headers: headers, body: encodedBody).timeout(timeoutDuration);
          break;
        case 'PATCH':
          response = await http.patch(url, headers: headers, body: encodedBody).timeout(timeoutDuration);
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers, body: encodedBody).timeout(timeoutDuration);
          break;
        default:
          throw Exception('지원하지 않는 HTTP 메서드입니다: $method');
      }

      // 서버로부터 정상적인 응답이 왔을 때
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 응답 본문이 비어있지 않으면 JSON 파싱
        if (response.body.isNotEmpty) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          return decoded as Map<String, dynamic>;
        }
        return {}; // Content가 없는 경우(201/204 등) 처리
      } else {
        // 서버에서 반환한 에러 메시지가 있는지 확인
        String errorMsg = '서버 오류가 발생했습니다.';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded['message'] != null) {
            errorMsg = decoded['message'];
          }
        } catch (_) {}
        
        throw ApiException(
          statusCode: response.statusCode,
          message: errorMsg,
        );
      }
    } on SocketException {
      // 인터넷 연결이 안 되어 있거나 서버가 응답하지 않을 때
      throw ApiException(message: '인터넷 연결이 끊어졌거나 서버와 연결할 수 없습니다. 네트워크 상태를 확인해주세요.');
    } on TimeoutException {
      // 요청 시간이 초과되었을 때
      throw ApiException(message: '서버 요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.');
    } on FormatException {
      // JSON 파싱 에러
      throw ApiException(message: '잘못된 데이터 형식입니다.');
    } catch (e) {
      // 그 외 알 수 없는 에러
      if (e is ApiException) rethrow; // 이미 잡힌 ApiException은 그대로 전달
      throw ApiException(message: '알 수 없는 에러가 발생했습니다: $e');
    }
  }


  // ==========================================
  // 1. 사용자 및 인증 (Auth & User)
  // ==========================================

  /// 회원가입
  Future<void> signUp({required String email, required String password, required String nickname}) async {
    await _callApi(
      '/api/v1/auth/signup',
      method: 'POST',
      body: {
        'email': email,
        'password': password,
        'nickname': nickname,
      },
      requiresAuth: false,
    );
  }

  /// 로그인
  /// 로그인 성공 시 토큰(accessToken, refreshToken)을 반환합니다.
  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    final response = await _callApi(
      '/api/v1/auth/login',
      method: 'POST',
      body: {
        'email': email,
        'password': password,
      },
      requiresAuth: false,
    );
    // 보통 data 블록 안에 토큰들이 있습니다.
    return response['data'] ?? response; 
  }

  /// 내 프로필 및 신뢰도 조회
  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _callApi(
      '/api/v1/users/me',
      method: 'GET',
    );
    return response['data'] ?? response;
  }


  // ==========================================
  // 2. Q&A (질문 및 답변)
  // ==========================================

  /// 질문 작성
  Future<void> postQuestion({
    required String title,
    required String content,
    required String category,
    required double latitude,
    required double longitude,
  }) async {
    await _callApi(
      '/api/v1/questions',
      method: 'POST',
      body: {
        'title': title,
        'content': content,
        'category': category,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  /// 질문 목록 조회 (페이징)
  Future<List<dynamic>> getQuestions({int page = 0, int size = 10}) async {
    final response = await _callApi(
      '/api/v1/questions?page=$page&size=$size',
      method: 'GET',
      requiresAuth: false, // 혹은 정책에 따라 true
    );
    return response['data'] ?? [];
  }

  /// 질문 상세 및 답변 목록 조회
  Future<Map<String, dynamic>> getQuestionDetail({required int questionId}) async {
    final response = await _callApi(
      '/api/v1/questions/$questionId',
      method: 'GET',
    );
    return response['data'] ?? response;
  }

  /// 답변 작성
  Future<void> postAnswer({required int questionId, required String content}) async {
    await _callApi(
      '/api/v1/questions/$questionId/answers',
      method: 'POST',
      body: {
        'content': content,
      },
    );
  }

  /// 답변 채택
  Future<void> acceptAnswer({required int questionId, required int answerId}) async {
    await _callApi(
      '/api/v1/questions/$questionId/answers/$answerId/accept',
      method: 'PATCH',
    );
  }


  // ==========================================
  // 3. 지도 및 현지 정보 (Map & Pins)
  // ==========================================

  /// 지도 핀 등록
  Future<void> postPin({
    required double latitude,
    required double longitude,
    required String pinType,
    required String title,
    required String description,
  }) async {
    await _callApi(
      '/api/v1/pins',
      method: 'POST',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'pinType': pinType,
        'title': title,
        'description': description,
      },
    );
  }

  /// 현재 화면 영역 내 핀 목록 조회 (Bounding Box)
  Future<List<dynamic>> getPinsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final response = await _callApi(
      '/api/v1/pins?minLat=$minLat&maxLat=$maxLat&minLng=$minLng&maxLng=$maxLng',
      method: 'GET',
    );
    return response['data'] ?? [];
  }
}
