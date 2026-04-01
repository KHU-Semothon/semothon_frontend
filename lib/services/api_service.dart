import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/map_block.dart';
import '../models/community_post.dart';

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

  // ==========================================
  // 5. 커뮤니티 게시글 (Community Posts)
  // ==========================================

  // Mock 모드 전용 게시글 저장소 (서버 역할)
  static final List<CommunityPost> _mockPosts = [
    CommunityPost(
      id: '1', username: 'q7wekr7', isVerified: false,
      title: '후쿠오카 밤에 혼자 돌아다녀도 괜찮나요?',
      preview: '편의점이나 돈키호테 들렸다가 늦게 숙소 돌아갈 것 같은데 괜찮은 분위기인...',
      timeAgo: '1분 전', likes: 1, comments: 3, bookmarks: 0,
      hasThumbnail: false, category: '화장실', country: '일본',
      createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
    CommunityPost(
      id: '2', username: 'vkdllie_999', isVerified: true,
      title: '시부야 곧 비 올 것 같아요',
      preview: '하늘 색이 좀 수상한데 우산있는 사람 거의 없음..',
      timeAgo: '6분 전', likes: 6, comments: 2, bookmarks: 1,
      hasThumbnail: true, category: '쇼핑', country: '일본',
      createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
    ),
    CommunityPost(
      id: '3', username: 'r1o8mlk_', isVerified: false,
      title: '일본 지하철 환승 어렵나요?',
      preview: '도쿄 처음 가는데 노선이 너무 많아서 걱정돼요ㅠㅠ',
      timeAgo: '9분 전', likes: 5, comments: 10, bookmarks: 3,
      hasThumbnail: false, category: '유적', country: '일본',
      createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
    ),
    CommunityPost(
      id: '4', username: 'zxnr291', isVerified: true,
      title: '도쿄에서 현지인 많이 가는 라멘집 알려주세요!',
      preview: '관광지 말고 진짜 맛있는 곳 가고 싶어요!!',
      timeAgo: '16분 전', likes: 12, comments: 4, bookmarks: 9,
      hasThumbnail: false, category: '식당', country: '일본',
      createdAt: DateTime.now().subtract(const Duration(minutes: 16)),
    ),
    CommunityPost(
      id: '5', username: 'tokyolover22', isVerified: false,
      title: '오사카에서 교토 당일치기 가능할까요?',
      preview: '신칸센 타면 금방이라던데 어떤 코스로 다녀오는 게 좋을지 추천 부탁드려요',
      timeAgo: '23분 전', likes: 8, comments: 7, bookmarks: 2,
      hasThumbnail: true, category: '유적', country: '일본',
      createdAt: DateTime.now().subtract(const Duration(minutes: 23)),
    ),
    CommunityPost(
      id: '6', username: 'beijing_trip', isVerified: false,
      title: '베이징 만리장성 입장료 얼마예요?',
      preview: '어른 기준 얼마인지 알고 싶어요. 예약은 온라인으로 해야 하나요?',
      timeAgo: '3시간 전', likes: 7, comments: 5, bookmarks: 2,
      hasThumbnail: false, category: '유적', country: '중국',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    CommunityPost(
      id: '7', username: 'shanghai_food', isVerified: true,
      title: '상하이 현지 식당 추천해주세요!',
      preview: '샤오롱바오 맛집이나 현지인들이 자주 가는 음식점 알려주시면 감사해요.',
      timeAgo: '4시간 전', likes: 19, comments: 11, bookmarks: 4,
      hasThumbnail: true, category: '식당', country: '중국',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    CommunityPost(
      id: '8', username: 'nyc_explorer', isVerified: false,
      title: '뉴욕 Times Square 근처 쇼핑 명소',
      preview: 'H&M, Zara 말고 뉴욕에서만 살 수 있는 특이한 쇼핑 장소 추천해주세요!',
      timeAgo: '5시간 전', likes: 14, comments: 6, bookmarks: 8,
      hasThumbnail: false, category: '쇼핑', country: '미국',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    CommunityPost(
      id: '9', username: 'london_walker', isVerified: true,
      title: '런던 버킹엄 궁전 근위병 교대식 시간 알려주세요',
      preview: '오전 10시라고 들었는데 계절마다 다르다고도 해서요.',
      timeAgo: '6시간 전', likes: 22, comments: 8, bookmarks: 5,
      hasThumbnail: false, category: '유적', country: '영국',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];

  /// 5-1. 커뮤니티 게시글 목록 조회
  /// [categories] 카테고리 필터 (빈 Set이면 전체)
  /// [countries]  나라 필터 (빈 Set이면 전체)
  /// [sort]       정렬 기준 (latest·popular·comments)
  Future<List<CommunityPost>> getPosts({
    Set<String> categories = const {},
    Set<String> countries  = const {},
    String sort = 'latest',
    int page = 0,
    int size = 20,
  }) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _mockPosts.where((p) {
        final categoryOk = categories.isEmpty || categories.contains(p.category);
        final countryOk  = countries.isEmpty  || countries.contains(p.country);
        return categoryOk && countryOk;
      }).toList();
    }

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
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      _mockPosts.insert(0, post); // 최신순 맨 앞에 추가
      return;
    }

    try {
      await _dio.post('/api/v1/posts', data: post.toJson());
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message;
      throw Exception('게시글 등록 실패: $errorMsg');
    }
  }
}
