import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/community_post.dart';
import '../models/save_folder.dart';
import '../models/my_comment.dart';
import '../models/map_block.dart';
import '../models/folder.dart';

// ─────────────────────────────────────────────────────────────
// 사용자 정의 예외
// ─────────────────────────────────────────────────────────────
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException({this.statusCode, required this.message});

  @override
  String toString() => 'ApiException(${statusCode ?? '-'}): $message';
}

// ─────────────────────────────────────────────────────────────
// ApiService — 싱글톤
// ─────────────────────────────────────────────────────────────
class ApiService {
  static const String baseUrl = 'https://daramjwi.com';
  static const String _tokenKey = 'accessToken'; // SharedPreferences 키

  // 싱글톤
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ── 토큰 관리 ────────────────────────────────────────────────

  /// 로그인 후 발급받은 Access Token을 기기에 저장합니다.
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// 저장된 Access Token을 불러옵니다. 없으면 null.
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// 로그아웃 시 저장된 토큰을 삭제합니다.
  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// 현재 로그인 여부 확인
  Future<bool> isLoggedIn() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  // ── 내부 HTTP 헬퍼 ───────────────────────────────────────────

  Future<Map<String, String>> _buildHeaders({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json; charset=UTF-8'};
    if (auth) {
      final token = await _getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// HTTP 응답을 공통 포맷으로 파싱하고, 에러 시 ApiException을 던집니다.
  Map<String, dynamic> _parse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    String msg = '서버 오류 (${res.statusCode})';
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['message'] != null) msg = body['message'] as String;
    } catch (_) {}
    throw ApiException(statusCode: res.statusCode, message: msg);
  }

  Future<Map<String, dynamic>> _get(String path, {bool auth = true}) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl$path'), headers: await _buildHeaders(auth: auth))
          .timeout(const Duration(seconds: 10));
      return _parse(res);
    } on SocketException {
      throw ApiException(message: '네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw ApiException(message: '서버 응답 시간이 초과되었습니다.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: '오류: $e');
    }
  }

  Future<Map<String, dynamic>> _post(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl$path'),
              headers: await _buildHeaders(auth: auth),
              body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 10));
      return _parse(res);
    } on SocketException {
      throw ApiException(message: '네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw ApiException(message: '서버 응답 시간이 초과되었습니다.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: '오류: $e');
    }
  }

  Future<Map<String, dynamic>> _patch(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    try {
      final res = await http
          .patch(Uri.parse('$baseUrl$path'),
              headers: await _buildHeaders(auth: auth),
              body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 10));
      return _parse(res);
    } on SocketException {
      throw ApiException(message: '네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw ApiException(message: '서버 응답 시간이 초과되었습니다.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: '오류: $e');
    }
  }

  Future<void> _delete(String path, {bool auth = true}) async {
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl$path'),
              headers: await _buildHeaders(auth: auth))
          .timeout(const Duration(seconds: 10));
      _parse(res);
    } on SocketException {
      throw ApiException(message: '네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw ApiException(message: '서버 응답 시간이 초과되었습니다.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: '오류: $e');
    }
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      // 명세서 2-2: data.content 배열 (페이징)
      final inner = data['content']
          ?? data['questions']
          ?? data['items']
          ?? data['answers']
          ?? data['pins']
          ?? [];
      if (inner is List) return inner;
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────
  // 1. 인증 (Auth & User)
  // ─────────────────────────────────────────────────────────────

  /// 1-1. 회원가입
  Future<void> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    await _post('/api/v1/auth/signup',
        body: {'email': email, 'password': password, 'nickname': nickname},
        auth: false);
  }

  /// 1-2. 로그인 — 성공 시 토큰을 자동으로 기기에 저장합니다.
  /// Returns: { accessToken, userId, nickname }
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _post('/api/v1/auth/login',
        body: {'email': email, 'password': password}, auth: false);
    final data = res['data'] as Map<String, dynamic>? ?? {};

    // 토큰 및 기본 정보 저장
    if (data['accessToken'] != null) {
      await saveToken(data['accessToken'] as String);
      final prefs = await SharedPreferences.getInstance();
      if (data['nickname'] != null) {
        await prefs.setString('cachedNickname', data['nickname'] as String);
      }
      if (data['userId'] != null) {
        await prefs.setString('userId', data['userId'].toString());
      }
    }
    return data;
  }

  /// 로그아웃 (저장된 모든 인증 정보 삭제)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove('cachedNickname');
    await prefs.remove('userId');
  }

  /// 1-3. 내 프로필 및 신뢰도 조회
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final res = await _get('/api/v1/users/me');
      return res['data'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return {
        'nickname': prefs.getString('cachedNickname') ?? '',
        'trustScore': 0,
      };
    }
  }

  /// 1-4. 프로필 수정 (닉네임, 아바타 이미지 경로)
  Future<Map<String, dynamic>> updateProfile({
    required String nickname,
    String? avatarPath,
  }) async {
    // 아바타 이미지가 있으면 먼저 업로드
    String? avatarUrl;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final urls = await uploadMedia([avatarPath]);
      if (urls.isNotEmpty) avatarUrl = urls.first;
    }
    final body = <String, dynamic>{'nickname': nickname};
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
    final res = await _patch('/api/v1/users/me', body: body);
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Q&A (질문 및 답변)
  // ─────────────────────────────────────────────────────────────

  /// 2-1. 질문 목록 조회 (페이징)
  Future<List<CommunityPost>> getQuestions({
    String? category,
    int page = 0,
    int size = 10,
  }) async {
    String path = '/api/v1/questions?page=$page&size=$size';
    if (category != null && category.isNotEmpty) path += '&category=$category';
    final res = await _get(path, auth: false);
    return _extractList(res['data'])
        .map<CommunityPost>(
            (e) => CommunityPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 2-2. 질문 상세 및 답변 조회
  Future<Map<String, dynamic>> getQuestionDetail(String questionId) async {
    final res = await _get('/api/v1/questions/$questionId');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// 2-3. 질문 등록 — 성공 시 questionId(String) 반환
  Future<String?> createQuestion({
    required String title,
    required String content,
    required String category,
    String? locationKeyword,
    String? country,
    double? latitude,
    double? longitude,
    List<String>? mediaUrls,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'content': content,
      'category': category,
      if (locationKeyword != null && locationKeyword.isNotEmpty)
        'locationKeyword': locationKeyword,
      if (country != null && country.isNotEmpty) 'country': country,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (mediaUrls != null && mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
    };
    debugPrint('[createQuestion] 요청 body: $body');
    final res = await _post('/api/v1/questions', body: body);
    debugPrint('[createQuestion] 응답: $res');
    final data = res['data'];
    if (data is Map) {
      return data['questionId']?.toString() ?? data['id']?.toString();
    }
    return null;
  }

  /// 2-4. 답변 작성
  Future<void> postAnswer(String questionId, String content) async {
    await _post('/api/v1/questions/$questionId/answers',
        body: {'content': content, 'mediaUrls': []});
  }

  /// 2-5. 답변 채택
  Future<void> acceptAnswer(String answerId) async {
    await _post('/api/v1/answers/$answerId/accept');
  }

  /// 2-6. 미디어 파일 업로드 (이미지/동영상)
  /// Returns: 업로드된 파일의 URL 목록
  Future<List<String>> uploadMedia(List<String> filePaths) async {
    final token = await _getToken();
    final List<String> uploadedUrls = [];
    for (final path in filePaths) {
      final request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/api/v1/media/upload'));
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(await http.MultipartFile.fromPath('file', path));
      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        if (data?['uploadedUrls'] != null) {
          uploadedUrls.addAll(
              List<String>.from(data!['uploadedUrls'] as List));
        }
      }
    }
    return uploadedUrls;
  }

  /// 2-7. 좋아요 토글 (좋아요 / 좋아요 취소)
  /// Returns: { isLiked: bool, likeCount: int }
  Future<Map<String, dynamic>> toggleQuestionLike(String questionId) async {
    final res = await _post('/api/v1/questions/$questionId/like');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// 게시물 신고
  Future<void> reportPost(String postId) async {
    await _post('/api/v1/questions/$postId/report');
  }

  /// 북마크 토글
  Future<void> toggleBookmark(String postId) async {
    await _post('/api/v1/questions/$postId/bookmark');
  }

  /// 내가 쓴 글 목록
  Future<List<CommunityPost>> getMyPosts() async {
    final res = await _get('/api/v1/questions/my');
    return _extractList(res['data'])
        .map<CommunityPost>(
            (e) => CommunityPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 내가 좋아요한 글 목록
  Future<List<CommunityPost>> getLikedPosts() async {
    final res = await _get('/api/v1/questions/liked');
    return _extractList(res['data'])
        .map<CommunityPost>(
            (e) => CommunityPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 신고 내역
  Future<List<CommunityPost>> getReportedPosts() async {
    final res = await _get('/api/v1/questions/reported');
    return _extractList(res['data'])
        .map<CommunityPost>(
            (e) => CommunityPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 내가 단 댓글 목록
  Future<List<MyComment>> getMyComments() async {
    final res = await _get('/api/v1/answers/my');
    return _extractList(res['data'])
        .map<MyComment>(
            (e) => MyComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 3. 지도 및 핀 (Map & Pins)
  // ─────────────────────────────────────────────────────────────

  /// 3-1. 지도 핀 등록
  Future<void> postPin({
    required double latitude,
    required double longitude,
    required String pinType,
    String? title,
    String? description,
  }) async {
    await _post('/api/v1/pins', body: {
      'latitude': latitude,
      'longitude': longitude,
      'pinType': pinType,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
    });
  }

  /// 3-2. 현재 화면 영역 내 핀 목록 조회 (Bounding Box)
  Future<List<dynamic>> getPinsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final res = await _get(
      '/api/v1/pins?minLat=$minLat&maxLat=$maxLat&minLng=$minLng&maxLng=$maxLng',
      auth: false,
    );
    return res['data'] as List? ?? [];
  }

  // 지도 구역(MapBlock) 조회 — 명세서 3-2: GET /api/v1/blocks (지도 카메라 이동 시 렌더링)
  Future<List<MapBlock>> getBlocksInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final res = await _get(
        '/api/v1/blocks?minLat=$minLat&maxLat=$maxLat&minLng=$minLng&maxLng=$maxLng',
        auth: false);
    return _extractList(res['data'])
        .map<MapBlock>((e) => MapBlock.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 4. 저장 폴더 (Save Folders)
  // ─────────────────────────────────────────────────────────────

  /// 내 저장 폴더 목록 조회
  Future<List<SaveFolder>> getFolders() async {
    final res = await _get('/api/v1/folders');
    final data = res['data'];
    List<dynamic> list = [];
    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = (data['folders'] ?? data['content'] ?? []) as List;
    }
    return list
        .map<SaveFolder>(
            (e) => SaveFolder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 폴더 생성 — SaveFolder 반환
  Future<SaveFolder> createFolder(String name, {String? imagePath}) async {
    // 이미지가 있으면 먼저 업로드
    String? thumbnailUrl;
    if (imagePath != null && imagePath.isNotEmpty) {
      final urls = await uploadMedia([imagePath]);
      if (urls.isNotEmpty) thumbnailUrl = urls.first;
    }
    final body = <String, dynamic>{'name': name};
    if (thumbnailUrl != null) body['thumbnailUrl'] = thumbnailUrl;
    final res = await _post('/api/v1/folders', body: body);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    return SaveFolder(
      id: data['folderId']?.toString() ?? data['id']?.toString() ?? '',
      name: name,
      postCount: 0,
      thumbnailUrl: thumbnailUrl,
    );
  }

  /// 폴더에 게시물 저장
  Future<void> addPostToFolder(String folderId, String postId) async {
    await _post('/api/v1/folders/$folderId/questions/$postId');
  }

  /// 폴더에서 게시물 제거 (4-3과 대칭)
  Future<void> removePostFromFolder(String folderId, String postId) async {
    await _delete('/api/v1/folders/$folderId/questions/$postId');
  }

  /// 폴더 이름 수정
  Future<void> renameFolder(String folderId, String newName) async {
    await _patch('/api/v1/folders/$folderId', body: {'name': newName});
  }

  /// 폴더 삭제
  Future<void> deleteFolder(String folderId) async {
    await _delete('/api/v1/folders/$folderId');
  }

  /// 폴더 순서 저장
  Future<void> reorderFolders(List<String> orderedIds) async {
    await _post('/api/v1/folders/order', body: {'folderIds': orderedIds});
  }

  /// 폴더 내 저장된 게시물 목록 조회
  Future<List<CommunityPost>> getPostsInFolder(String folderId,
      {int page = 0, int size = 20}) async {
    final res = await _get(
        '/api/v1/folders/$folderId/questions?page=$page&size=$size');
    return _extractList(res['data'])
        .map<CommunityPost>(
            (e) => CommunityPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 5. 폴더 핀 (API 명세 4-5)
  // ─────────────────────────────────────────────────────────────

  /// 폴더 내 화면 영역 핀 목록 조회 (Bounding Box) — 명세서 4-5
  Future<List<FolderPin>> getFolderPinsInBounds({
    required String folderId,   // String으로 실제 사용
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final res = await _get(
      '/api/v1/folders/$folderId/pins?minLat=$minLat&maxLat=$maxLat&minLng=$minLng&maxLng=$maxLng',
    );
    return _extractList(res['data'])
        .map<FolderPin>(
            (e) => FolderPin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 6. 지도 핀 등록/삭제/투표 (API 명세서 3-1, 3-2 기준)
  // ─────────────────────────────────────────────────────────────

  /// BlockType → 서버 pinType 문자열 변환 (명세서: DANGER, RESTAURANT, CAUTION, CAFE, ETC)
  static String _toPinType(BlockType type) {
    switch (type) {
      case BlockType.hazard:     return 'DANGER';
      case BlockType.cultural:   return 'CAUTION';
      case BlockType.restaurant: return 'RESTAURANT';
      case BlockType.cafe:       return 'CAFE';
      case BlockType.tip:        return 'ETC';
      case BlockType.other:      return 'ETC';
    }
  }

  /// 서버 pinType → BlockType 변환
  static BlockType _fromPinType(String? pinType) {
    switch ((pinType ?? '').toUpperCase()) {
      case 'DANGER':     return BlockType.hazard;
      case 'CAUTION':    return BlockType.cultural;
      case 'RESTAURANT': return BlockType.restaurant;
      case 'CAFE':       return BlockType.cafe;
      case 'ETC':        return BlockType.tip;
      default:           return BlockType.other;
    }
  }

  /// 지도 구역 등록 (명세서 3-1: POST /api/v1/blocks, 구역 설정 시 호출)
  Future<void> postBlock(MapBlock block) async {
    final body = <String, dynamic>{
      'id':        block.id,
      'latitude':  block.center.latitude,
      'longitude': block.center.longitude,
      'radius':    block.radius,          // double, 단위: m
      'type':      block.type.name,       // 소문자 그대로: hazard, cultural, restaurant, cafe, tip, other
      'comment':   block.comment,
      'createdAt': block.createdAt.toIso8601String(),
    };
    await _post('/api/v1/blocks', body: body);
  }

  /// 지도 구역 삭제
  Future<void> deleteBlock(String blockId) async {
    await _delete('/api/v1/blocks/$blockId');
  }

  /// 지도 구역 투표 — 유지(keep=true) 또는 삭제(keep=false)
  Future<MapBlock> voteBlock(String blockId, bool isKeep) async {
    final res = await _post(
      '/api/v1/blocks/$blockId/vote',
      body: {'isKeep': isKeep},
    );
    final data = res['data'] as Map<String, dynamic>? ?? {};
    return MapBlock.fromJson(data);
  }
}

