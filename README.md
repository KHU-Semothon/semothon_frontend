# Semothon Frontend

A beautiful, gray-scale modern Flutter mobile application featuring sign-in, map-based discovery, community Q&A, and user profiles.

## Features Design
- **Sign In / Sign Up Screen**: Clean email inputs and modern social login buttons (Google, Apple)
- **Map Home Screen**: Scaffolded for map integration including a custom search bar, draggable bottom sheet, and dynamic filtering visual styles.
- **Q&A Screen**: Scrollable community board featuring real-time searches and profile lists using customizable widgets.
- **My Page Screen**: Informational dashboard with gradient progress bars and nested settings menus.

---

## 🚀 실행 가이드 (Getting Started)

### 1. 필요 환경 설정 (Prerequisites)
이 앱을 실행하려면 개발 환경이 구축되어 있어야 합니다.
- **Flutter SDK**가 설치되어 있어야 합니다. 
- iOS 앱 실행을 위해서는 **Xcode** 및 **CocoaPods**가 필요합니다.
- Android 앱 실행을 위해서는 **Android Studio**가 필요합니다.

### 2. 패키지 의존성 설치 (Install Dependencies)
터미널에서 이 프로젝트 폴더(`semothon_frontend`)로 진입한 후 아래 명령어를 실행하여 필요한 패키지를 다운로드 받습니다.
```bash
flutter pub get
```

### 3. 에뮬레이터/시뮬레이터 실행
앱을 띄울 가상 기기를 실행하세요.
- **iOS**: Mac에서 `Simulator` 앱을 실행
- **Android**: Android Studio 내부 Device Manager에서 가상 기기(AVD)를 실행
*(실제 스마트폰을 USB/WiFi로 연결하셔도 됩니다.)*

### 4. 앱 실행 (Run the App)
명령어 창에 아래 코드를 입력하여 앱을 실행하세요.
```bash
flutter run
```
> **Tip**: VS Code, Android Studio 등 IDE를 사용하시는 경우 상단의 `Run (F5)` 버튼을 클릭하시면 즉시 빌드 및 실행이 가능합니다. 개발 중 코드를 수정하고 저장하면 자동으로 리로드(Hot Reload)가 적용됩니다.

---

## 📂 주요 폴더 구조 (Project Structure)

```text
lib/
├── main.dart                      # 앱 진입점 및 전역 테마(폰트, 컬러, 패딩 등) 설정
├── screens/
│   ├── main_scaffold.dart         # BottomNavigationBar 기반의 라우팅 뼈대
│   ├── map_home_screen.dart       # 지도 탭 (검색바, 지도 뷰, 바텀시트)
│   ├── my_page_screen.dart        # 마이페이지 탭 (프로필, 경험치바, 메뉴)
│   ├── qa_screen.dart             # Q&A 커뮤니티 탭
│   └── sign_in_screen.dart        # 첫 시작 (로그인 / 회원가입 화면)
└── widgets/                       # 공통 디자인 컴포넌트 모음
    ├── custom_search_bar.dart     # 라운드 검색바 위젯
    ├── list_item.dart             # 리스트 반복을 위한 UI 단위 컴포넌트
    └── social_login_button.dart   # 테두리가 있는 커스텀 소셜 로그인 버튼
```
