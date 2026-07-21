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

- 공용 비밀번호: `remote-data/main.json`의 `access.teamPassword`
- 로그인 허용: `access.login_all`이 `"Y"`이면 누구나, 그 외 값이면 `access.allowedIds`에 등록된 아이디만 가능
- `admin` 아이디는 관리자 악보 업로드·삭제 메뉴를 표시합니다.

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
4. 행사 및 연습 일정
5. 관리자용 팀원·공지·일정 관리

## 관리자 악보 관리

`admin` 아이디로 로그인하면 악보 자료실에 업로드와 삭제 기능이 표시됩니다.

최초 사용 시 GitHub Fine-grained personal access token을 입력해야 합니다.

1. GitHub Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Repository access에서 `SerenLucent/AST`만 선택
3. Repository permissions의 `Contents`를 `Read and write`로 설정
4. 생성된 토큰을 앱의 GitHub 관리자 연결 창에 입력

토큰은 앱 코드나 GitHub JSON에 저장되지 않고 Android 기기의 암호화된 보안 저장소에만 보관됩니다.
