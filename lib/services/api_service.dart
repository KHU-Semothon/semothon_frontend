import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/map_block.dart';

class ApiService {
  // 개발 편의를 위한 가짜 서버 통신 설정 (실제 서버가 준비되면 false로 변경하세요)
  static const bool useMock = true;

  late final Dio _dio;
  // 실제 서버 환경에 맞게 변경 (안드로이드 에뮬레이터 로컬: http://10.0.2.2:8080)
  static const String baseUrl = 'http://10.0.2.2:8080';

  // 싱글톤 패턴 적용
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        responseType: ResponseType.json,
      ),
    );

    // 공통 응답 및 토큰 처리를 위한 인터셉터 추가
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 공통 Content-Type
          options.headers['Content-Type'] = 'application/json';

          // 로그인/회원가입은 Authorization 토큰 불필요
          if (options.path != '/api/v1/auth/login' && options.path != '/api/v1/auth/signup') {
            final prefs = await SharedPreferences.getInstance();
            final accessToken = prefs.getString('accessToken');
            
            if (accessToken != null) {
              // ⚠️ Bearer 단어 뒤에 띄어쓰기 1칸 포함
              options.headers['Authorization'] = 'Bearer $accessToken';
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // 정상 응답
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          // 공통 에러 핸들링
          return handler.next(e);
        },
      ),
    );
  }

  /// API 응답 공통 포맷 처리 헬퍼
  /// { "status": 200, "message": "...", "data": {...} }
  Map<String, dynamic>? _extractBody(Response response) {
    if (response.data != null && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }

  // ==========================================
  // 1. 사용자 및 인증 (Auth & User)
  // ==========================================

  /// 1-1. 회원가입
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    if (useMock) {
      await Future.delayed(const Duration(seconds: 1));
      return {'status': 200, 'message': '가짜 회원가입 성공'};
    }

    try {
      final response = await _dio.post('/api/v1/auth/signup', data: {
        'email': email,
        'password': password,
        'nickname': nickname,
      });
      return _extractBody(response) ?? {};
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('회원가입 실패: $errorMsg');
    }
  }

  /// 1-2. 로그인
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (useMock) {
      await Future.delayed(const Duration(seconds: 1));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', 'mock_token_123');
      return {'status': 200, 'message': '가짜 로그인 성공', 'data': {'accessToken': 'mock_token_123'}};
    }

    try {
      final response = await _dio.post('/api/v1/auth/login', data: {
        'email': email,
        'password': password,
      });
      
      final body = _extractBody(response);
      final data = body?['data'];
      
      // JWT 토큰 스토리지 저장
      if (data != null && data['accessToken'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', data['accessToken']);
      }
      
      return body ?? {};
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('로그인 실패: $errorMsg');
    }
  }

  /// 1-3. 내 프로필 및 신뢰도 조회
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await _dio.get('/api/v1/users/me');
      final body = _extractBody(response);
      return body?['data'] ?? body ?? {};
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('프로필 조회 실패: $errorMsg');
    }
  }


  // ==========================================
  // 2. Q&A (질문 및 답변)
  // ==========================================

  Future<void> postQuestion({
    required String title,
    required String content,
    required String category,
    required double latitude,
    required double longitude,
  }) async {
    await _dio.post('/api/v1/questions', data: {
      'title': title,
      'content': content,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<List<dynamic>> getQuestions({int page = 0, int size = 10}) async {
    final response = await _dio.get('/api/v1/questions', queryParameters: {
      'page': page,
      'size': size,
    });
    final body = _extractBody(response);
    return body?['data'] ?? [];
  }

  Future<Map<String, dynamic>> getQuestionDetail({required int questionId}) async {
    final response = await _dio.get('/api/v1/questions/$questionId');
    final body = _extractBody(response);
    return body?['data'] ?? body ?? {};
  }

  Future<void> postAnswer({required int questionId, required String content}) async {
    await _dio.post('/api/v1/questions/$questionId/answers', data: {
      'content': content,
    });
  }

  Future<void> acceptAnswer({required int questionId, required int answerId}) async {
    await _dio.patch('/api/v1/questions/$questionId/answers/$answerId/accept');
  }


  // ==========================================
  // 3. 지도 및 현지 정보 (Map & Pins)
  // ==========================================

  Future<void> postPin({
    required double latitude,
    required double longitude,
    required String pinType,
    required String title,
    required String description,
  }) async {
    await _dio.post('/api/v1/pins', data: {
      'latitude': latitude,
      'longitude': longitude,
      'pinType': pinType,
      'title': title,
      'description': description,
    });
  }

  Future<List<dynamic>> getPinsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final response = await _dio.get('/api/v1/pins', queryParameters: {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
    });
    final body = _extractBody(response);
    return body?['data'] ?? [];
  }

  /// 로그아웃 처리
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
  }

  // ==========================================
  // 4. 구역 공유 (Map Blocks)
  // ==========================================

  // Mock 모드 전용 공유 저장소 (서버 역할)
  // 실제 서버 연동 시에는 이 리스트 없이 서버 DB가 처리합니다.
  static final List<MapBlock> _mockBlocks = [];

  /// 4-1. 현재 지도 화면 범위 내 구역 목록 조회
  /// [minLat] 남쪽 위도, [maxLat] 북쪽 위도
  /// [minLng] 서쪽 경도, [maxLng] 동쪽 경도
  Future<List<MapBlock>> getBlocksInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      // 만료된 항목 먼저 정리
      _mockBlocks.removeWhere((b) => b.isExpired);
      // 현재 화면 범위 안에 중심점이 포함된 블록만 반환
      return _mockBlocks.where((b) {
        return b.center.latitude >= minLat &&
            b.center.latitude <= maxLat &&
            b.center.longitude >= minLng &&
            b.center.longitude <= maxLng;
      }).toList();
    }

    try {
      final response = await _dio.get('/api/v1/blocks', queryParameters: {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
      });
      final body = _extractBody(response);
      final list = (body?['data'] as List?) ?? [];
      return list.map((e) => MapBlock.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('구역 목록 조회 실패: $errorMsg');
    }
  }

  /// 4-2. 새 구역 등록 (서버에 저장하여 다른 사용자와 공유)
  Future<void> postBlock(MapBlock block) async {
    if (useMock) {
      await Future.delayed(const Duration(seconds: 1));
      _mockBlocks.add(block);
      return;
    }

    try {
      await _dio.post('/api/v1/blocks', data: block.toJson());
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('구역 등록 실패: $errorMsg');
    }
  }
}
