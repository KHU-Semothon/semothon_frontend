# 서버 연동 가이드

현재 `api_service.dart` 파일은 서버가 아직 완성되지 않은 상태에서 원활한 UI 화면 진행 테스트가 가능하도록 **가짜 응답 모드(Mock Mode)**로 설정되어 있습니다.

백엔드 서버 개발이 완료되어 실제 서버와 연결해야 할 때, 다음 단계를 따라 코드를 수정해 주세요.

## 1. 가짜 응답 모드(Mock) 끄기
현재 서버 요청을 가로채서 성공(200 OK)으로 인식하게 만들어주는 가짜 모드를 꺼야 합니다.

- **위치**: `lib/services/api_service.dart` (파일 상단 5번째 줄 부근)
- **변경 사항**: `useMock` 변수를 `true`에서 `false`로 변경합니다.

```dart
class ApiService {
  // 변경 전 (현재)
  // static const bool useMock = true;
  
  // 변경 후 (실제 통신을 할 때)
  static const bool useMock = false;
```

## 2. 실제 서버 주소 입력하기
백엔드 연동을 위해 통신을 시도할 실제 목적지 주소(URL)를 입력해야 합니다.

- **위치**: `lib/services/api_service.dart` (파일 상단 9번째 줄 부근)
- **변경 사항**: `baseUrl` 변수에 백엔드 팀이 공유해 준 실제 서버 접속 주소를 기입합니다.

```dart
  // 테스트 기기별 기본 예시 주소:
  // - 안드로이드 에뮬레이터 로컬: 'http://10.0.2.2:8080'
  // - iOS 시뮬레이터 로컬: 'http://127.0.0.1:8080'
  // - 운영/배포된 실제 서버: 'https://api.yourdomain.com'

  // 아래 주소를 실제 서버 주소로 변경하세요.
  static const String baseUrl = 'http://10.0.2.2:8080';
```

위의 두 단계를 거치면(mock 끄기 & 실제 baseUrl 기입) 로그인 및 회원가입 시 실제로 백엔드 서버와 연결되어 정상적인 계정 인증 처리가 이루어집니다.

---

## 3. 구역 공유 API 연동

구역(MapBlock) 데이터를 서버에 저장하고, 현재 지도 화면 범위에 맞춰 다른 사용자의 구역도 불러오는 기능입니다.  
현재는 `useMock = true` 상태이므로 앱 내부 메모리(`ApiService._mockBlocks`)가 서버 역할을 합니다.

### 3-1. 구역 목록 조회 (화면 범위 기반)

- **현재(Mock)**: `ApiService._mockBlocks` 에서 경계 좌표 범위 내 항목만 필터링하여 반환
- **실제 서버 엔드포인트**: `GET /api/v1/blocks`
- **쿼리 파라미터**:

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `minLat` | double | 화면 남쪽(아래) 위도 |
| `maxLat` | double | 화면 북쪽(위) 위도 |
| `minLng` | double | 화면 서쪽(왼쪽) 경도 |
| `maxLng` | double | 화면 동쪽(오른쪽) 경도 |

- **응답 형식 (예시)**:
```json
{
  "status": 200,
  "data": [
    {
      "id": "1234567890",
      "latitude": 37.5665,
      "longitude": 126.9780,
      "radius": 100.0,
      "type": "hazard",
      "comment": "이 근처 도로 공사 중 주의하세요",
      "createdAt": "2026-04-02T00:00:00.000Z"
    }
  ]
}
```

### 3-2. 새 구역 등록

- **현재(Mock)**: 1초 딜레이 후 `ApiService._mockBlocks`에 추가
- **실제 서버 엔드포인트**: `POST /api/v1/blocks`
- **요청 본문(Body)**:
```json
{
  "id": "1234567890",
  "latitude": 37.5665,
  "longitude": 126.9780,
  "radius": 100.0,
  "type": "hazard",
  "comment": "이 근처 도로 공사 중 주의하세요",
  "createdAt": "2026-04-02T00:00:00.000Z"
}
```
- `type` 값: `"hazard"` (위험) 또는 `"cultural"` (문화)

### 관련 코드 위치

- **메서드**: `lib/services/api_service.dart` → `getBlocksInBounds()`, `postBlock()`
- **호출 위치**: `lib/screens/map_home_screen.dart` → `_fetchBlocksInCurrentBounds()` (onCameraIdle), `_showRegistrationDialog()` (저장 버튼)

---

## 4. 커뮤니티 게시글 API 연동

커뮤니티 게시글을 서버에서 불러오고 등록하는 기능입니다.  
현재는 `useMock = true` 상태이므로 `ApiService._mockPosts` 정적 리스트가 서버 역할을 합니다.

### 4-1. 게시글 목록 조회 (필터 + 정렬)

- **현재(Mock)**: `_mockPosts`에서 카테고리·나라 조건으로 필터링하여 반환
- **실제 서버 엔드포인트**: `GET /api/v1/posts`
- **쿼리 파라미터**:

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `categories` | String | 카테고리 필터 (쉼표 구분, 예: `식당,쇼핑`) |
| `countries` | String | 나라 필터 (쉼표 구분, 예: `일본,중국`) |
| `sort` | String | 정렬 기준: `latest`(최신순) · `popular`(인기순) · `comments`(댓글순) |
| `page` | int | 페이지 번호 (0부터 시작) |
| `size` | int | 페이지 당 개수 (기본값 20) |

- **응답 형식 (예시)**:
```json
{
  "status": 200,
  "data": [
    {
      "id": "1",
      "username": "q7wekr7",
      "isVerified": false,
      "title": "후쿠오카 밤에 혼자 돌아다녀도 괜찮나요?",
      "preview": "편의점이나 돈키호테 들렸다가 늦게 숙소 돌아갈 것 같은데...",
      "timeAgo": "1분 전",
      "likes": 1,
      "comments": 3,
      "bookmarks": 0,
      "hasThumbnail": false,
      "category": "화장실",
      "country": "일본",
      "createdAt": "2026-04-02T00:00:00.000Z"
    }
  ]
}
```

### 4-2. 게시글 등록

- **현재(Mock)**: 500ms 딜레이 후 `_mockPosts` 맨 앞에 추가
- **실제 서버 엔드포인트**: `POST /api/v1/posts`
- **요청 본문(Body)**:
```json
{
  "title": "후쿠오카 밤에 혼자 돌아다녀도 괜찮나요?",
  "preview": "편의점이나 돈키호테 들렸다가 늦게 숙소 돌아갈 것 같은데...",
  "category": "화장실",
  "country": "일본"
}
```
- `category` 값: `식당` · `화장실` · `쇼핑` · `유적`
- `country` 값: `일본` · `중국` · `미국` · `영국`

### 관련 코드 위치

- **모델**: `lib/models/community_post.dart` → `CommunityPost.fromJson()`, `.toJson()`
- **메서드**: `lib/services/api_service.dart` → `getPosts()`, `createPost()`
- **호출 위치**: `lib/screens/qa_screen.dart` → `_fetchPosts()` (화면 진입·필터·정렬 변경 시 자동 호출)
