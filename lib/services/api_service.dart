import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/folder.dart';
import '../models/question.dart';
import '../models/pin.dart';

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


  // ==========================================
  // 1. 사용자 및 인증 (Auth & User)
  // ==========================================

  /// 1-1. 회원가입
  Future<void> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
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

  /// 1-2. 로그인
  /// 성공 시 { accessToken, userId, nickname }을 반환합니다.
  /// 발급받은 accessToken을 전역 상태나 스토리지에 저장해 주세요.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
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
  }


  // ==========================================
  // 3. 지도 및 현지 정보 (Map & Pins)
  // ==========================================

  /// 3-1. 지도 핀 등록
  /// [pinType]: DANGER | RESTAURANT | CAUTION
  /// Returns: 생성된 pinId
  Future<int> postPin({
    required double latitude,
    required double longitude,
    required String pinType,
    required String title,
    required String description,
  }) async {
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
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
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
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final response = await _callApi(
      '/api/v1/folders/$folderId/pins?minLat=$minLat&maxLat=$maxLat&minLng=$minLng&maxLng=$maxLng',
      method: 'GET',
    );
    final List<dynamic> data = response['data'] ?? [];
    return data
        .map((json) => FolderPin.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
