# AST 아카펠라 팀 앱

Flutter로 만든 Android 우선 팀 전용 앱입니다. 현재는 공용 비밀번호 로그인, 최초 ID 닉네임 등록, 자동 로그인, 메인 대시보드까지 구현되어 있습니다.

## 실행

```powershell
flutter pub get
flutter run
```

Android APK 생성:

```powershell
flutter build apk --release
```

## 현재 샘플 로그인

- 공용 비밀번호: `harmony2026`
- `admin` 아이디는 향후 관리자 역할 연결을 위한 예약 샘플입니다.

운영 전 공용 비밀번호 검사는 Firebase 같은 서버 측으로 이동해야 합니다. 현재 값은 화면 흐름 확인용으로 앱 코드에 들어 있습니다.

## 폴더 구조

```text
lib/                  Flutter 앱 코드
assets/images/        앱 내장 기본 이미지
remote-data/          GitHub에서 읽을 JSON 원본
remote-assets/images/ GitHub에서 읽을 팀원 사진과 배너
remote-assets/scores/ 다운로드할 악보
android/              Android 네이티브 프로젝트
```

## 다음 구현 순서

1. Firebase 사용자 및 게시글 저장소 연결
2. GitHub Raw `main.json` 동기화와 오프라인 캐시
3. 팀원 소개 목록/상세
4. 악보 목록/시스템 저장 창 다운로드
5. 행사 및 연습 일정
6. 관리자 GitHub 인증과 업로드
