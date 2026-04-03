<<<<<<< HEAD
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/folder.dart';
import '../models/question.dart';
import '../models/pin.dart';
=======
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/map_block.dart';
import '../models/community_post.dart';
import '../models/save_folder.dart';
import '../models/my_comment.dart';
>>>>>>> 20076dbd0a1e24d981e4bf4167b2cd71d58d2666

class ApiService {
<<<<<<< HEAD
  // 실제 서버의 baseUrl로 변경해야 합니다.
  static const String baseUrl = 'https://daramjwi.com';

  static const String _tokenKey = 'access_token';

  /// 로그인 후 받은 액세스 토큰을 기기에 저장합니다.
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// 저장된 액세스 토큰을 불러옵니다. 없으면 null 반환.
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// 로그아웃 시 저장된 토큰을 삭제합니다.
  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
=======
  // useMock = false: 실제 서버(daramjwi.com)와 통신합니다.
  static const bool useMock = false;

  late final Dio _dio;
  // 실제 서버 주소
  static const String baseUrl = 'http://daramjwi.com';

  // 싱글톤 패턴 적용
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
>>>>>>> 20076dbd0a1e24d981e4bf4167b2cd71d58d2666
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

    // JWT 인증 인터셉터
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['Content-Type'] = 'application/json';

<<<<<<< HEAD
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
        if (response.body.isNotEmpty) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          return decoded as Map<String, dynamic>;
        }
        return {}; // Content가 없는 경우(201/204 등) 처리
      } else {
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
      throw ApiException(message: '인터넷 연결이 끊어졌거나 서버와 연결할 수 없습니다. 네트워크 상태를 확인해주세요.');
    } on TimeoutException {
      throw ApiException(message: '서버 요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.');
    } on FormatException {
      throw ApiException(message: '잘못된 데이터 형식입니다.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: '알 수 없는 에러가 발생했습니다: $e');
    }
  }

  /// 2-6에서 사용하는 multipart/form-data 파일 업로드 내부 함수
  Future<List<String>> _uploadMultipart(String endpoint, File file) async {
    final token = await _getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>;
        return List<String>.from(data['uploadedUrls'] as List);
      } else {
        throw ApiException(statusCode: response.statusCode, message: '파일 업로드에 실패했습니다.');
      }
    } on SocketException {
      throw ApiException(message: '인터넷 연결이 끊어졌거나 서버와 연결할 수 없습니다.');
    } on TimeoutException {
      throw ApiException(message: '파일 업로드 시간이 초과되었습니다.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: '파일 업로드 중 오류가 발생했습니다: $e');
    }
  }

=======
          // 로그인/회원가입/토큰갱신은 Authorization 토큰 불필요
          final noAuth = [
            '/api/v1/auth/login',
            '/api/v1/auth/signup',
            '/api/v1/auth/refresh',
          ];
          if (!noAuth.contains(options.path)) {
            final prefs = await SharedPreferences.getInstance();
            final accessToken = prefs.getString('accessToken');
            if (accessToken != null) {
              options.headers['Authorization'] = 'Bearer $accessToken';
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) => handler.next(response),
        onError: (DioException e, handler) async {
          // 401 응답 시 Refresh Token으로 자동 재발급
          if (e.response?.statusCode == 401) {
            try {
              final newToken = await _refreshAccessToken();
              if (newToken != null) {
                // 원래 요청에 새 토큰 적용 후 재시도
                final opts = e.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newToken';
                final retryResp = await _dio.fetch(opts);
                return handler.resolve(retryResp);
              }
            } catch (_) {
              // Refresh도 실패 → 토큰 제거 (로그아웃)
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('accessToken');
              await prefs.remove('refreshToken');
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  /// Access Token 재발급 (Refresh Token 활용)
  Future<String?> _refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');
    if (refreshToken == null) return null;

    final response = await _dio.post(
      '/api/v1/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final body = response.data as Map<String, dynamic>?;
    final newAccess = body?['data']?['accessToken'] as String?;
    if (newAccess != null) {
      await prefs.setString('accessToken', newAccess);
    }
    return newAccess;
  }

  /// API 응답 공통 포맷 처리 헬퍼
  /// { "status": 200, "message": "...", "data": {...} }
  dynamic _extractBody(Response response) {
    return response.data;
  }

  /// 'data' 키로 감싸져 있는지 확인하고 실제 데이터만 반환
  dynamic _extractData(dynamic body) {
    if (body is Map && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
>>>>>>> 20076dbd0a1e24d981e4bf4167b2cd71d58d2666

  // ==========================================
  // 1. 사용자 및 인증 (Auth & User)
  // ==========================================

  /// 1-1. 회원가입
<<<<<<< HEAD
  Future<void> signUp({
=======
  Future<Map<String, dynamic>> signUp({
>>>>>>> 20076dbd0a1e24d981e4bf4167b2cd71d58d2666
    required String email,
    required String password,
    required String nickname,
  }) async {
<<<<<<< HEAD
    await _callApi(
      '/api/v1/auth/signup',
      method: 'POST',
      body: {
=======
    try {
      final response = await _dio.post('/api/v1/auth/signup', data: {
>>>>>>> 20076dbd0a1e24d981e4bf4167b2cd71d58d2666
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

<<<<<<< HEAD
  /// 1-2. 로그인
  /// 성공 시 { accessToken, userId, nickname }을 반환합니다.
  /// 발급받은 accessToken을 전역 상태나 스토리지에 저장해 주세요.
=======
  /// 1-2. 로그인 (JWT 발급)
>>>>>>> 20076dbd0a1e24d981e4bf4167b2cd71d58d2666
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
<<<<<<< HEAD
    final response = await _callApi(
      '/api/v1/auth/login',
      method: 'POST',
      body: {
        'email': email,
        'password': password,
      },
      requiresAuth: false,
    );
    return response['data'] ?? response;
  }

  /// 1-3. 내 프로필 및 신뢰도 조회
  /// 마이페이지 렌더링에 사용하세요.
=======
    try {
      final response = await _dio.post('/api/v1/auth/login', data: {
        'email': email,
        'password': password,
      });
      final body = _extractBody(response);
      final data = _extractData(body);
      
      final prefs = await SharedPreferences.getInstance();

      // Access Token 저장
      if (data?['accessToken'] != null) {
        await prefs.setString('accessToken', data['accessToken'] as String);
      }
      // Refresh Token 저장
      if (data?['refreshToken'] != null) {
        await prefs.setString('refreshToken', data['refreshToken'] as String);
      }
      // 로그인 응답에 포함된 사용자 정보 캐시
      // 서버 응답 키: nickname, userId, username (camelCase 기준)
      if (data?['nickname'] != null) {
        await prefs.setString('cachedNickname', data['nickname'] as String);
      } else if (data?['username'] != null) {
        await prefs.setString('cachedNickname', data['username'] as String);
      }
      if (data?['userId'] != null) {
        await prefs.setString('userId', data['userId'].toString());
      } else if (data?['id'] != null) {
        await prefs.setString('userId', data['id'].toString());
      }

      return body ?? {};
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('로그인 실패: $errorMsg');
    }
  }

  /// 1-3. 내 프로필 및 신뢰도 조회
  /// API 명세 기반 camelCase 키: username, nickname, profileImage,
  /// trustScore(0~100), livingYears, visitCount
>>>>>>> 20076dbd0a1e24d981e4bf4167b2cd71d58d2666
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await _dio.get('/api/v1/users/me');
      final body = _extractBody(response);
      final data = body?['data'] ?? body ?? {};

      // 로컬 캐시에서 닉네임 보완 (API 없을 때 폴백)
      if ((data['nickname'] == null) && (data['username'] == null)) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cachedNickname');
        if (cached != null) data['nickname'] = cached;
      }

      return data as Map<String, dynamic>;
    } on DioException catch (_) {
      // 서버 미응답 시 캐시된 정보라도 반환
      final prefs = await SharedPreferences.getInstance();
      return {
        'nickname': prefs.getString('cachedNickname') ?? '',
        'profileImage': '',
        'trustScore': 0,
      };
    }
  }

  /// 1-4. 프로필 수정 (닉네임 + 선택적 아바타 이미지)
  Future<Map<String, dynamic>> updateProfile({
    required String nickname,
    String? avatarPath, // 로컬 파일 경로
  }) async {
    try {
      final FormData formData;
      if (avatarPath != null) {
        formData = FormData.fromMap({
          'nickname': nickname,
          'avatar': await MultipartFile.fromFile(avatarPath, filename: 'avatar.jpg'),
        });
      } else {
        formData = FormData.fromMap({'nickname': nickname});
      }
      final response = await _dio.patch(
        '/api/v1/users/me',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final body = _extractBody(response);
      final data = _extractData(body);
      return (data is Map<String, dynamic>) ? data : {};
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('프로필 수정 실패: $errorMsg');
    }
  }

  /// 1-6. 게시물 좋아요
  Future<void> toggleLike(String postId) async {
    try {
      await _dio.post('/api/v1/posts/$postId/like');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('좋아요 처리 실패: $errorMsg');
    }
  }

  /// 1-7. 게시글 신고 (작성자 신뢰도 -10%)
  /// POST /api/v1/posts/{postId}/report
  Future<void> reportPost(String postId) async {
    try {
      await _dio.post('/api/v1/posts/$postId/report');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('신고 실패: $errorMsg');
    }
  }

  /// 1-8. 게시물 북마크 (저장) 토글
  Future<void> toggleBookmark(String postId) async {
    try {
      await _dio.post('/api/v1/posts/$postId/bookmark');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('북마크 처리 실패: $errorMsg');
    }
  }

  /// 1-9. 댓글 작성
  Future<void> postComment(String postId, String content) async {
    try {
      await _dio.post('/api/v1/questions/$postId/answers', data: {'content': content});
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('댓글 작성 실패: $errorMsg');
    }
  }

  /// 로그아웃 (Access + Refresh 토큰 모두 제거)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
  }

  /// 로그인 여부 확인
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    return token != null && token.isNotEmpty;
  }

  // ==========================================
  // 2. Q&A (질문 및 답변) 명세서 기반
  // ==========================================

<<<<<<< HEAD
  /// 2-1. 질문 작성
  /// [mediaUrls]: 2-6 미디어 업로드 API로 먼저 업로드 후 반환된 URL 목록
  /// [category]: CULTURE | DANGER | PRICE | ETC
  /// Returns: 생성된 questionId
  Future<int> postQuestion({
    required String title,
    required String content,
    required String category,
    required String locationKeyword,
    required double latitude,
    required double longitude,
    List<String> mediaUrls = const [],
  }) async {
    final response = await _callApi(
      '/api/v1/questions',
      method: 'POST',
      body: {
        'title': title,
        'content': content,
        'category': category,
        'locationKeyword': locationKeyword,
        'latitude': latitude,
        'longitude': longitude,
        'mediaUrls': mediaUrls,
      },
    );
    return (response['data']['questionId'] as num).toInt();
  }

  /// 2-2. 질문 목록 조회 (페이징 + 카테고리 필터)
  /// [category]: 선택적 카테고리 필터 (CULTURE, DANGER, PRICE, ETC)
  /// [page]: 0부터 시작 (기본값 0)
  /// [size]: 페이지당 개수 (기본값 10)
  /// Returns: QuestionPage (content 리스트 + 총 페이지 수 등)
  Future<QuestionPage> getQuestions({
    String? category,
    int page = 0,
    int size = 10,
  }) async {
    String endpoint = '/api/v1/questions?page=$page&size=$size';
    if (category != null && category.isNotEmpty) {
      endpoint += '&category=$category';
    }
    final response = await _callApi(
      endpoint,
      method: 'GET',
      requiresAuth: false,
    );
    return QuestionPage.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// 2-3. 질문 상세 및 답변 목록 조회
  /// 로그인 상태에서 토큰을 보내면 isLiked가 정확하게 반영됩니다.
  /// 비회원은 requiresAuth: false로 호출하세요.
  Future<QuestionDetail> getQuestionDetail({
    required int questionId,
    bool requiresAuth = true,
  }) async {
    final response = await _callApi(
      '/api/v1/questions/$questionId',
      method: 'GET',
      requiresAuth: requiresAuth,
    );
    return QuestionDetail.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// 2-4. 답변 작성
  /// [mediaUrls]: 2-6 미디어 업로드 API로 먼저 업로드 후 반환된 URL 목록
  /// Returns: 생성된 answerId
  Future<int> postAnswer({
    required int questionId,
    required String content,
    List<String> mediaUrls = const [],
  }) async {
    final response = await _callApi(
      '/api/v1/questions/$questionId/answers',
      method: 'POST',
      body: {
        'content': content,
        'mediaUrls': mediaUrls,
      },
    );
    return (response['data']['answerId'] as num).toInt();
  }

  /// 2-5. 답변 채택
  /// 채택 시 해당 답변자의 신뢰도 점수가 상승합니다.
  Future<void> acceptAnswer({required int answerId}) async {
    await _callApi(
      '/api/v1/answers/$answerId/accept',
      method: 'POST',
    );
  }

  /// 2-6. 미디어 파일 업로드 (이미지/동영상)
  /// 질문/답변 작성 전, 이 API로 파일을 먼저 업로드하고
  /// 반환된 URL을 postQuestion/postAnswer의 mediaUrls에 전달하세요.
  /// Returns: 업로드된 파일의 정적 URL 목록
  Future<List<String>> uploadMedia({required File file}) async {
    return _uploadMultipart('/api/v1/media/upload', file);
  }

  /// 2-7. 질문 좋아요 토글 (좋아요 / 좋아요 취소)
  /// 버튼 클릭 시 이 API 하나만 호출하면 됩니다.
  /// Returns: { isLiked: bool, likeCount: int }
  Future<Map<String, dynamic>> toggleQuestionLike({required int questionId}) async {
    final response = await _callApi(
      '/api/v1/questions/$questionId/like',
      method: 'POST',
    );
    return response['data'] as Map<String, dynamic>;
=======
  /// 2-1. 질문 목록 조회
  Future<List<CommunityPost>> getQuestions({
    String? category,
    int page = 0,
    int size = 10,
  }) async {
    try {
      final response = await _dio.get('/api/v1/questions', queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        'page': page,
        'size': size,
      });

      debugPrint('[getQuestions] status: ${response.statusCode}');
      debugPrint('[getQuestions] raw data: ${response.data}');

      final body = response.data;

      // 응답 구조 유연하게 처리
      List<dynamic> list = [];
      if (body is List) {
        list = body;
      } else if (body is Map) {
        final inner = body['data'] ?? body;
        if (inner is List) {
          list = inner;
        } else if (inner is Map) {
          final content = inner['content'] ?? inner['questions'] ?? inner['items'];
          if (content is List) list = content;
        }
      }

      debugPrint('[getQuestions] 파싱된 목록 수: ${list.length}');
      return list.map<CommunityPost>((e) => CommunityPost.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('[getQuestions] DioException: status=${e.response?.statusCode}, msg=${e.response?.data}');
      final errorMsg = e.response?.data?['message'] ?? e.response?.data?.toString() ?? e.message;
      throw Exception('질문 목록 조회 실패: $errorMsg');
    } catch (e) {
      debugPrint('[getQuestions] 예외 발생: $e');
      throw Exception('게시글 파싱 오류: $e');
    }
  }

  /// 2-2. 질문 상세 조회 (isLiked 포함)
  Future<Map<String, dynamic>> getQuestionDetail(String questionId) async {
    try {
      final response = await _dio.get('/api/v1/questions/$questionId');
      debugPrint('[getQuestionDetail] status: ${response.statusCode}');
      debugPrint('[getQuestionDetail] raw: ${response.data}');

      final body = response.data;
      Map<String, dynamic> result = {};

      if (body is Map<String, dynamic>) {
        // {status, message, data: {...}} 형태
        if (body.containsKey('data') && body['data'] is Map) {
          result = Map<String, dynamic>.from(body['data'] as Map);
        } else {
          result = body;
        }
      }

      debugPrint('[getQuestionDetail] 파싱 결과: keys=${result.keys.toList()}');
      debugPrint('[getQuestionDetail] answers: ${result['answers']}');
      return result;
    } on DioException catch (e) {
      debugPrint('[getQuestionDetail] 오류: status=${e.response?.statusCode}, body=${e.response?.data}');
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('질문 상세 조회 실패: $errorMsg');
    }
  }

  /// 2-3. 질문 등록 - questionId 반환
  Future<String?> createQuestion({
    required String title,
    required String content,
    required String category,
    String? locationKeyword,
    String? country,
    List<String>? mediaUrls,
  }) async {
    try {
      // 토큰 존재 여부 사전 확인
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      if (token == null || token.isEmpty) {
        throw Exception('로그인이 필요합니다. 다시 로그인 후 시도해주세요.');
      }

      final requestBody = {
        'title': title,
        'content': content,
        'category': category,
        if (locationKeyword != null && locationKeyword.isNotEmpty) 'locationKeyword': locationKeyword,
        if (country != null && country.isNotEmpty) 'country': country,
        if (mediaUrls != null && mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
      };
      debugPrint('[createQuestion] 요청 body: $requestBody');
      final response = await _dio.post('/api/v1/questions', data: requestBody);
      debugPrint('[createQuestion] 응답 status: ${response.statusCode}, data: ${response.data}');

      // 인스턴스 questionId 추출
      final body = response.data;
      String? newId;
      if (body is Map) {
        final data = body['data'] ?? body;
        if (data is Map) {
          newId = data['questionId']?.toString() ?? data['id']?.toString();
        }
      }
      return newId;
    } on DioException catch (e) {
      debugPrint('[createQuestion] DioException: status=${e.response?.statusCode}');
      debugPrint('[createQuestion] 응답 body: ${e.response?.data}');
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인 후 시도해주세요.');
      }
      if (statusCode == 403) {
        throw Exception('게시물 등록 권한이 없습니다. 로그인 상태를 확인해주세요.');
      }
      // 서버가 List (validation error array) 또는 Map 으로 응답할 수 있음
      final rawData = e.response?.data;
      String errorMsg;
      if (rawData is List && rawData.isNotEmpty) {
        // [{"field": "...", "message": "..."}] 형태
        final first = rawData.first;
        errorMsg = (first is Map ? first['message']?.toString() : null) ?? rawData.toString();
      } else if (rawData is Map) {
        errorMsg = rawData['message']?.toString() ?? rawData.toString();
      } else {
        errorMsg = e.message ?? '알 수 없는 오류';
      }
      throw Exception('질문 등록 실패: $errorMsg');
    }
  }

  /// 2-4. 질문 좋아요 토글
  Future<Map<String, dynamic>> toggleQuestionLike(String questionId) async {
    try {
      final response = await _dio.post('/api/v1/questions/$questionId/like');
      return _extractData(_extractBody(response)) as Map<String, dynamic>;
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('좋아요 처리 실패: $errorMsg');
    }
  }

  /// 2-5. 답변 작성
  Future<void> postAnswer(String questionId, String content) async {
    try {
      debugPrint('[postAnswer] questionId=$questionId, content=$content');
      final response = await _dio.post(
        '/api/v1/questions/$questionId/answers',
        data: {'content': content},
      );
      debugPrint('[postAnswer] 성공: status=${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('[postAnswer] DioException: status=${e.response?.statusCode}, body=${e.response?.data}');
      final rawData = e.response?.data;
      String errorMsg;
      if (rawData is List && rawData.isNotEmpty) {
        final first = rawData.first;
        errorMsg = (first is Map ? first['message']?.toString() : null) ?? rawData.toString();
      } else if (rawData is Map) {
        errorMsg = rawData['message']?.toString() ?? rawData.toString();
      } else {
        errorMsg = e.message ?? '알 수 없는 오류';
      }
      throw Exception('답변 작성 실패: $errorMsg');
    }
  }

  /// 2-6. 답변 채택
  Future<void> acceptAnswer(String answerId) async {
    try {
      await _dio.post('/api/v1/answers/$answerId/accept');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('답변 채택 실패: $errorMsg');
    }
  }

  /// 2-8. 내가 쓴 글 목록
  Future<List<CommunityPost>> getMyPosts() async {
    try {
      final response = await _dio.get('/api/v1/questions/my');
      debugPrint('[getMyPosts] status: ${response.statusCode}, data: ${response.data}');
      final body = response.data;
      List<dynamic> list = [];
      if (body is List) {
        list = body;
      } else if (body is Map) {
        final inner = body['data'] ?? body;
        if (inner is List) {
          list = inner;
        } else if (inner is Map) {
          list = (inner['content'] ?? inner['questions'] ?? []) as List;
        }
      }
      return list.map<CommunityPost>((e) => CommunityPost.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('[getMyPosts] 오류: ${e.response?.statusCode} ${e.response?.data}');
      throw Exception('내가 쓴 글을 불러오지 못했습니다: ${e.response?.data?['message'] ?? e.message}');
    }
>>>>>>> 20076dbd0a1e24d981e4bf4167b2cd71d58d2666
  }

  /// 2-9. 내가 단 댓글 목록
  Future<List<MyComment>> getMyComments() async {
    try {
      final response = await _dio.get('/api/v1/answers/my');
      debugPrint('[getMyComments] status: ${response.statusCode}, data: ${response.data}');
      final body = response.data;
      List<dynamic> list = [];
      if (body is List) {
        list = body;
      } else if (body is Map) {
        final inner = body['data'] ?? body;
        if (inner is List) {
          list = inner;
        } else if (inner is Map) {
          list = (inner['content'] ?? inner['answers'] ?? []) as List;
        }
      }
      return list.map<MyComment>((e) => MyComment.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('[getMyComments] 오류: ${e.response?.statusCode} ${e.response?.data}');
      throw Exception('내가 단 댓글을 불러오지 못했습니다: ${e.response?.data?['message'] ?? e.message}');
    }
  }

  /// 2-10. 내가 좋아요한 글 목록
  Future<List<CommunityPost>> getLikedPosts() async {
    try {
      final response = await _dio.get('/api/v1/questions/liked');
      debugPrint('[getLikedPosts] status: ${response.statusCode}, data: ${response.data}');
      final body = response.data;
      List<dynamic> list = [];
      if (body is List) {
        list = body;
      } else if (body is Map) {
        final inner = body['data'] ?? body;
        if (inner is List) {
          list = inner;
        } else if (inner is Map) {
          list = (inner['content'] ?? inner['questions'] ?? []) as List;
        }
      }
      return list.map<CommunityPost>((e) => CommunityPost.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('[getLikedPosts] 오류: ${e.response?.statusCode} ${e.response?.data}');
      throw Exception('좋아요한 글을 불러오지 못했습니다: ${e.response?.data?['message'] ?? e.message}');
    }
  }

  /// 2-11. 신고 내역
  Future<List<CommunityPost>> getReportedPosts() async {
    try {
      final response = await _dio.get('/api/v1/questions/reported');
      debugPrint('[getReportedPosts] status: ${response.statusCode}, data: ${response.data}');
      final body = response.data;
      List<dynamic> list = [];
      if (body is List) {
        list = body;
      } else if (body is Map) {
        final inner = body['data'] ?? body;
        if (inner is List) {
          list = inner;
        } else if (inner is Map) {
          list = (inner['content'] ?? inner['questions'] ?? []) as List;
        }
      }
      return list.map<CommunityPost>((e) => CommunityPost.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('[getReportedPosts] 오류: ${e.response?.statusCode} ${e.response?.data}');
      throw Exception('신고 내역을 불러오지 못했습니다: ${e.response?.data?['message'] ?? e.message}');
    }
  }

  /// 2-7. 미디어 업로드 (멀티파트)
  Future<List<String>> uploadMedia(List<String> filePaths) async {
    try {
      final List<MultipartFile> files = [];
      for (final p in filePaths) {
        files.add(await MultipartFile.fromFile(p, filename: p.split('/').last));
      }
      final formData = FormData.fromMap({'files': files});
      final response = await _dio.post(
        '/api/v1/media/upload',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = _extractData(_extractBody(response));
      // data: { "uploadedUrls": ["..."] }
      if (data is Map && data.containsKey('uploadedUrls')) {
        return (data['uploadedUrls'] as List).map((e) => e.toString()).toList();
      }
      return (data is List) ? data.map((e) => e.toString()).toList() : [];
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('파일 업로드 실패: $errorMsg');
    }
  }

  // ==========================================
  // 3. 지도 및 현지 정보 (Map & Pins)
  // ==========================================

<<<<<<< HEAD
  /// 3-1. 지도 핀 등록
  /// [pinType]: DANGER | RESTAURANT | CAUTION
  /// Returns: 생성된 pinId
  Future<int> postPin({
=======
  /// 3-1. 핀 생성
  Future<void> postPin({
>>>>>>> 20076dbd0a1e24d981e4bf4167b2cd71d58d2666
    required double latitude,
    required double longitude,
    required String pinType,
  }) async {
<<<<<<< HEAD
    final response = await _callApi(
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
    return (response['data']['pinId'] as num).toInt();
  }

  /// 3-2. 현재 화면 영역 내 핀 목록 조회 (Bounding Box)
  /// 지도 카메라가 이동할 때마다 호출하여 마커를 렌더링합니다.
  /// Authorization: 불필요 (비회원 조회 가능)
  Future<List<MapPin>> getPinsInBounds({
=======
    try {
      await _dio.post('/api/v1/pins', data: {
        'latitude': latitude,
        'longitude': longitude,
        'pinType': pinType,
      });
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('핀 생성 실패: $errorMsg');
    }
  }

  /// 3-2. 범위 내 핀 목록 조회
  Future<List<dynamic>> getPinsInBounds({
>>>>>>> 20076dbd0a1e24d981e4bf4167b2cd71d58d2666
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
<<<<<<< HEAD
    final response = await _callApi(
      '/api/v1/pins?minLat=$minLat&maxLat=$maxLat&minLng=$minLng&maxLng=$maxLng',
      method: 'GET',
      requiresAuth: false,
    );
    final List<dynamic> data = response['data'] ?? [];
    return data.map((json) => MapPin.fromJson(json as Map<String, dynamic>)).toList();
  }


  // ==========================================
  // 4. 폴더 및 스크랩 (Folders & Scraps)
  // ==========================================

  /// 4-1. 폴더 생성
  /// Returns: 생성된 folderId
  Future<int> createFolder({required String name}) async {
    final response = await _callApi(
      '/api/v1/folders',
      method: 'POST',
      body: {'name': name},
    );
    return (response['data']['folderId'] as num).toInt();
  }

  /// 4-2. 내 폴더 목록 조회
  /// 스크랩 버튼 클릭 시 폴더 선택 UI 또는 마이페이지에 사용하세요.
  Future<List<Folder>> getMyFolders() async {
    final response = await _callApi(
      '/api/v1/folders',
      method: 'GET',
    );
    final List<dynamic> data = response['data'] ?? [];
    return data.map((json) => Folder.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// 4-3. 폴더에 게시물 저장 (스크랩)
  /// Request Body 없음 - Path Variable로만 처리됩니다.
  Future<void> scrapQuestionToFolder({
    required int folderId,
    required int questionId,
  }) async {
    await _callApi(
      '/api/v1/folders/$folderId/questions/$questionId',
      method: 'POST',
    );
  }

  /// 4-4. 폴더 내 게시물 목록 조회
  Future<List<FolderQuestion>> getFolderQuestions({required int folderId}) async {
    final response = await _callApi(
      '/api/v1/folders/$folderId/questions',
      method: 'GET',
    );
    final List<dynamic> data = response['data'] ?? [];
    return data
        .map((json) => FolderQuestion.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 4-5. 폴더 내 화면 영역 핀 목록 조회 (Bounding Box)
  /// 지도 화면을 움직일 때마다, 선택한 폴더 안의 게시물 중
  /// 현재 화면에 포함되는 핀 데이터만 불러와 마커를 렌더링합니다.
  Future<List<FolderPin>> getFolderPinsInBounds({
    required int folderId,
=======
    try {
      final response = await _dio.get('/api/v1/pins', queryParameters: {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
      });
      return _extractData(_extractBody(response)) as List? ?? [];
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('핀 목록 조회 실패: $errorMsg');
    }
  }

  // ==========================================
  // 4. 구역 공유 (Map Blocks)
  // ==========================================

  /// 4-1. 현재 지도 화면 범위 내 구역 목록 조회
  Future<List<MapBlock>> getBlocksInBounds({
>>>>>>> 20076dbd0a1e24d981e4bf4167b2cd71d58d2666
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
<<<<<<< HEAD
    final response = await _callApi(
      '/api/v1/folders/$folderId/pins?minLat=$minLat&maxLat=$maxLat&minLng=$minLng&maxLng=$maxLng',
      method: 'GET',
    );
    final List<dynamic> data = response['data'] ?? [];
    return data
        .map((json) => FolderPin.fromJson(json as Map<String, dynamic>))
        .toList();
=======
    try {
      final response = await _dio.get('/api/v1/blocks', queryParameters: {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
      });
      final body = _extractBody(response);
      final data = _extractData(body);
      final list = (data is List) ? data : [];
      return list.map((e) => MapBlock.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('구역 목록 조회 실패: $errorMsg');
    }
  }

  /// 4-2. 새 구역 등록
  Future<void> postBlock(MapBlock block) async {
    try {
      await _dio.post('/api/v1/blocks', data: block.toJson());
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('구역 등록 실패: $errorMsg');
    }
  }

  /// 4-3. 구역 투표 (유지/삭제)
  Future<MapBlock> voteBlock(String id, bool isKeep) async {
    try {
      final response = await _dio.post('/api/v1/blocks/$id/vote', data: {'isKeep': isKeep});
      final body = _extractBody(response);
      final data = _extractData(body);
      return MapBlock.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('투표 실패: $errorMsg');
    }
  }

  /// 4-4. 구역/핀 삭제
  Future<void> deleteBlock(String id) async {
    try {
      await _dio.delete('/api/v1/blocks/$id');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('삭제 실패: $errorMsg');
    }
  }

  // ==========================================
  // 5. 커뮤니티 게시글 (Community Posts)
  // ==========================================

  /// 5-1. 커뮤니티 게시글 목록 조회
  Future<List<CommunityPost>> getPosts({
    Set<String> categories = const {},
    Set<String> countries  = const {},
    String sort = 'latest',
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _dio.get('/api/v1/posts', queryParameters: {
        if (categories.isNotEmpty) 'categories': categories.join(','),
        if (countries.isNotEmpty)  'countries':  countries.join(','),
        'sort': sort,
        'page': page,
        'size': size,
      });
      final body = _extractBody(response);
      final data = _extractData(body);
      final list = (data is List) ? data : [];
      return list.map((e) => CommunityPost.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('게시글 목록 조회 실패: $errorMsg');
    }
  }

  /// 5-2. 커뮤니티 게시글 등록 (멀티미디어 지원)
  Future<void> createPost(CommunityPost post, {List<String>? imagePaths, String? videoPath}) async {
    try {
      // JSON 데이터를 Map으로 변환
      final Map<String, dynamic> postData = post.toJson();
      
      // FormData 구성을 위한 맵 생성
      final Map<String, dynamic> formDataMap = {...postData};

      // 이미지 파일 추가
      if (imagePaths != null && imagePaths.isNotEmpty) {
        final List<MultipartFile> imageFiles = [];
        for (final path in imagePaths) {
          imageFiles.add(await MultipartFile.fromFile(path, filename: path.split('/').last));
        }
        formDataMap['images'] = imageFiles;
      }

      // 동영상 파일 추가
      if (videoPath != null) {
        formDataMap['video'] = await MultipartFile.fromFile(videoPath, filename: videoPath.split('/').last);
      }

      final formData = FormData.fromMap(formDataMap);

      await _dio.post(
        '/api/v1/posts', 
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('게시글 등록 실패: $errorMsg');
    }
  }



  // ==========================================
  // 6. 저장 폴더 (Save Folders / 나의 취향)
  // ==========================================

  /// 6-1. 내 저장 폴더 목록 조회
  Future<List<SaveFolder>> getFolders() async {
    try {
      final response = await _dio.get('/api/v1/folders');
      final body = _extractBody(response);
      final data = _extractData(body);
      final List list = (data is List) ? data : (data is Map ? (data['folders'] ?? []) : []);
      return list.map((e) => SaveFolder.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('폴더 목록 조회 실패: $errorMsg');
    }
  }

  /// 6-2. 폴더 생성 (이미지 첨부 지원)
  Future<SaveFolder> createFolder(String name, {String? imagePath}) async {
    try {
      final dynamic requestData;
      final Options? options;

      if (imagePath != null) {
        requestData = FormData.fromMap({
          'name': name,
          'image': await MultipartFile.fromFile(imagePath, filename: 'folder_thumb.jpg'),
        });
        options = Options(contentType: 'multipart/form-data');
      } else {
        requestData = {'name': name};
        options = null;
      }

      debugPrint('[createFolder] 요청 body: $requestData');
      final response = await _dio.post(
        '/api/v1/folders',
        data: requestData,
        options: options,
      );
      debugPrint('[createFolder] 응답 status: ${response.statusCode}, data: ${response.data}');

      final body = response.data;
      dynamic responseData;
      if (body is Map && body.containsKey('data')) {
        responseData = body['data'];
      } else if (body is Map) {
        responseData = body;
      }

      if (responseData == null || responseData is! Map) {
        throw Exception('폴더 생성 응답 데이터가 없습니다.');
      }
      return SaveFolder.fromJson(responseData as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('[createFolder] DioException: status=${e.response?.statusCode}, body=${e.response?.data}');
      final rawData = e.response?.data;
      String errorMsg;
      if (rawData is List && rawData.isNotEmpty) {
        final first = rawData.first;
        errorMsg = (first is Map ? first['message']?.toString() : null) ?? rawData.toString();
      } else if (rawData is Map) {
        errorMsg = rawData['message']?.toString() ?? rawData.toString();
      } else {
        errorMsg = '서버 내부 오류가 발생했습니다.';
      }
      throw Exception('폴더 생성 실패: $errorMsg');
    } catch (e) {
      debugPrint('[createFolder] 예외: $e');
      throw Exception('폴더 생성 실패: $e');
    }
  }

  /// 6-3. 폴더 이름 수정
  Future<void> renameFolder(String folderId, String newName) async {
    try {
      await _dio.patch('/api/v1/folders/$folderId', data: {'name': newName});
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('폴더 이름 수정 실패: $errorMsg');
    }
  }

  /// 6-4. 폴더 삭제
  Future<void> deleteFolder(String folderId) async {
    try {
      await _dio.delete('/api/v1/folders/$folderId');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('폴더 삭제 실패: $errorMsg');
    }
  }

  /// 6-5. 폴더 순서 저장
  Future<void> reorderFolders(List<String> orderedIds) async {
    try {
      await _dio.put('/api/v1/folders/order', data: {'folderIds': orderedIds});
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('폴더 순서 저장 실패: $errorMsg');
    }
  }

  /// 6-6. 폴더에 게시글 저장
  Future<void> addPostToFolder(String folderId, String postId) async {
    try {
      await _dio.post('/api/v1/folders/$folderId/posts/$postId');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('게시글 저장 실패: $errorMsg');
    }
  }

  /// 6-7. 폴더에서 게시글 제거
  Future<void> removePostFromFolder(String folderId, String postId) async {
    try {
      await _dio.delete('/api/v1/folders/$folderId/posts/$postId');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('게시글 제거 실패: $errorMsg');
    }
  }

  /// 6-8. 폴더 내 저장된 게시글 목록 조회
  Future<List<CommunityPost>> getPostsInFolder(String folderId, {int page = 0, int size = 20}) async {
    try {
      final response = await _dio.get(
        '/api/v1/folders/$folderId/posts',
        queryParameters: {'page': page, 'size': size},
      );
      final body = _extractBody(response);
      final data = _extractData(body);
      final list = (data is List) ? data : [];
      return list.map((e) => CommunityPost.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('폴더 게시글 조회 실패: $errorMsg');
    }
>>>>>>> 20076dbd0a1e24d981e4bf4167b2cd71d58d2666
  }
}

