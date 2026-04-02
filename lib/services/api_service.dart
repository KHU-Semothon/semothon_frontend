import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/map_block.dart';
import '../models/community_post.dart';
import '../models/save_folder.dart';

class ApiService {
  // useMock = false: 실제 서버(daramjwi.com)와 통신합니다.
  static const bool useMock = false;

  late final Dio _dio;
  // 실제 서버 주소
  static const String baseUrl = 'http://daramjwi.com';

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

    // JWT 인증 인터셉터
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['Content-Type'] = 'application/json';

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

  /// 1-2. 로그인 (JWT 발급)
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/api/v1/auth/login', data: {
        'email': email,
        'password': password,
      });
      final body = _extractBody(response);
      final data = body?['data'];
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
      return body?['data'] ?? body ?? {};
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('프로필 수정 실패: $errorMsg');
    }
  }

  /// 1-6. 게시글 신고 (작성자 신뢰도 -10%)
  /// POST /api/v1/posts/{postId}/report
  Future<void> reportPost(String postId) async {
    try {
      await _dio.post('/api/v1/posts/$postId/report');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('신고 실패: $errorMsg');
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

  // ==========================================
  // 4. 구역 공유 (Map Blocks)
  // ==========================================

  /// 4-1. 현재 지도 화면 범위 내 구역 목록 조회
  Future<List<MapBlock>> getBlocksInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
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
      return MapBlock.fromJson(body?['data'] as Map<String, dynamic>);
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
      final list = (body?['data'] as List?) ?? [];
      return list.map((e) => CommunityPost.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('게시글 목록 조회 실패: $errorMsg');
    }
  }

  /// 5-2. 커뮤니티 게시글 등록
  Future<void> createPost(CommunityPost post) async {
    try {
      await _dio.post('/api/v1/posts', data: post.toJson());
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
      final list = (body?['data'] as List?) ?? [];
      return list.map((e) => SaveFolder.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('폴더 목록 조회 실패: $errorMsg');
    }
  }

  /// 6-2. 폴더 생성
  Future<SaveFolder> createFolder(String name) async {
    try {
      final response = await _dio.post('/api/v1/folders', data: {'name': name});
      final body = _extractBody(response);
      return SaveFolder.fromJson(body?['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('폴더 생성 실패: $errorMsg');
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
      final list = (body?['data'] as List?) ?? [];
      return list.map((e) => CommunityPost.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('폴더 게시글 조회 실패: $errorMsg');
    }
  }
}

