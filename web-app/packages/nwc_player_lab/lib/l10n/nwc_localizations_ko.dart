// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'nwc_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class NwcLocalizationsKo extends NwcLocalizations {
  NwcLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get scoreFolder => '악보 폴더';

  @override
  String get chooseScoreFolder => '폴더 선택';

  @override
  String get changeScoreFolder => '폴더 변경';

  @override
  String get folderBack => '뒤로';

  @override
  String get folderRefresh => '목록 새로고침';

  @override
  String get folderHelp =>
      '허용한 폴더에서 NWC·NWCTXT 파일과 하위 폴더만 표시합니다. 파일을 옮길 필요는 없습니다.';

  @override
  String get folderPermissionHelp =>
      '먼저 악보가 있는 폴더를 선택하고 접근을 허용해 주세요.\n\nAndroid 11 이상에서는 ‘다운로드’ 폴더 자체나 저장소 루트를 폴더로 허용할 수 없습니다. 그 안의 파일은 위의 ‘파일 열기’로 바로 열 수 있습니다. 하위 폴더는 선택할 수 있으며, 새 폴더를 만들 필요는 없습니다.';

  @override
  String get folderLoading => '현재 폴더의 목록을 읽는 중…';

  @override
  String get folderEmpty => '이 폴더에는 NWC·NWCTXT 파일이나 하위 폴더가 없습니다.';

  @override
  String get folderAccessError =>
      '폴더 또는 파일을 읽을 수 없습니다. 접근 권한이 해제되었거나 파일이 이동되었을 수 있습니다. 폴더를 다시 선택하거나 ‘파일 열기’를 이용해 주세요.';

  @override
  String get folderTimeout =>
      '저장소 응답이 지연되고 있습니다. 연결 상태를 확인한 뒤 목록을 새로고침하거나 ‘파일 열기’를 이용해 주세요.';

  @override
  String get exitAppTitle => '앱 종료';

  @override
  String get exitAppMessage => 'NWC Player를 종료할까요?';

  @override
  String get cancelExit => '취소';

  @override
  String get openFile => '파일 열기';

  @override
  String get openNwcFile => 'NWC 파일 열기';

  @override
  String get readingFile => '파일 읽는 중';

  @override
  String get performanceMenu => '연주 메뉴';

  @override
  String get partVolumes => '파트별 볼륨 조절';

  @override
  String get pitchAdjustment => '피치 조절 (반음)';

  @override
  String tonic(String note) {
    return '으뜸음 : $note';
  }

  @override
  String get originalPitch => '원음';

  @override
  String get pitchHelp => '조표가 바뀌는 구간별로 악보와 재생음을 함께 조절합니다.\n원본 파일은 변경되지 않습니다.';

  @override
  String fromBar(int bar) {
    return '$bar마디부터';
  }

  @override
  String barRange(int from, int to) {
    return '$from~$to마디';
  }

  @override
  String get lowerPitch => '반음 내리기';

  @override
  String get raisePitch => '반음 올리기';

  @override
  String get playback => '재생';

  @override
  String get startBar => '시작 마디';

  @override
  String get previousBar => '이전 마디';

  @override
  String get nextBar => '다음 마디';

  @override
  String get barUnit => '마디';

  @override
  String get lowerBpm => 'BPM 낮추기';

  @override
  String get raiseBpm => 'BPM 높이기';

  @override
  String get originalSpeed => '원래 속도';

  @override
  String get pause => '일시정지';

  @override
  String get resume => '재개';

  @override
  String get stop => '정지';

  @override
  String get playSelected => '체크된 파트 재생';

  @override
  String get playAll => '전체 재생';

  @override
  String get repeatSection => '구간 반복';

  @override
  String get start => '시작';

  @override
  String get end => '끝';

  @override
  String get playLoop => '구간 반복 재생';

  @override
  String get score => '악보';

  @override
  String get scoreSize => '악보 크기';

  @override
  String get zoomOut => '악보 축소';

  @override
  String get zoomIn => '악보 확대';

  @override
  String get landscape => '가로 보기';

  @override
  String get closeLandscape => '가로화면 닫기';

  @override
  String get followScore => '악보 따라가기';

  @override
  String get selectParts => '표시할 파트를 선택하세요';

  @override
  String get scrollMenu => '메뉴는 위아래로 스크롤';

  @override
  String playingBar(String bar) {
    return '재생중인 마디 : $bar';
  }

  @override
  String get addFavorite => '즐겨찾기 추가';

  @override
  String get removeFavorite => '즐겨찾기 해제';

  @override
  String get favorites => '즐겨찾기';

  @override
  String get appInformation => '앱 정보 및 개인정보처리방침';

  @override
  String get unlockPro => 'Pro 잠금 해제';

  @override
  String get lockedControl => 'Pro에서 사용 · 잠금 해제';

  @override
  String get exitPlayer => '플레이어 종료';

  @override
  String get favoriteTooLarge => '2MB를 넘는 파일은 즐겨찾기에 저장할 수 없습니다';

  @override
  String get playbackFinished => '전체 연주 완료';

  @override
  String get preparingPlayback => '준비 중';

  @override
  String get playing => '재생';

  @override
  String get resumedPlayback => '연주 재개';

  @override
  String get stoppedPlayback => '정지';

  @override
  String get preparingLoop => '구간 반복 준비 중';

  @override
  String loopStatus(int from, int to) {
    return '$from~$to마디 구간 반복';
  }

  @override
  String loopTitle(String name, int from, int to) {
    return '$name · $from~$to마디 반복';
  }

  @override
  String playbackProgress(String status, int bar, int bpm) {
    return '$status · $bar마디 · $bpm BPM';
  }

  @override
  String realtimeError(String error) {
    return '실시간 재생 오류: $error';
  }

  @override
  String readFailed(String error) {
    return '읽기 실패: $error';
  }

  @override
  String favoriteFailed(String error) {
    return '즐겨찾기 열기 실패: $error';
  }

  @override
  String playbackFailed(String error) {
    return '재생 실패: $error';
  }

  @override
  String loopFailed(String error) {
    return '구간 반복 실패: $error';
  }

  @override
  String get unexpectedError => '작업을 완료하지 못했습니다. 파일과 기기 상태를 확인하고 다시 시도해주세요.';

  @override
  String get invalidNwcString => '잘못된 NWC 문자열';

  @override
  String get emptyOrLargeScore => '빈 파일이거나 20MB를 넘는 악보입니다.';

  @override
  String get corruptCompressedScore =>
      '압축 악보가 손상됐거나 압축 해제 크기가 20MB를 넘습니다. 원본을 확인해주세요.';

  @override
  String get scoreTooLarge => '20MB 이하의 NWC 또는 NWCTXT 악보 파일을 선택해주세요.';

  @override
  String get invalidScore => 'NWC/NWCTXT 악보가 아니거나 파일이 손상되었습니다.';

  @override
  String get legacyScore =>
      '구형 NWC 바이너리(1.75/2.5)는 직접 지원하지 않습니다. NoteWorthy Composer 2.75에서 다시 저장하거나 NWCTXT로 내보낸 뒤 열어 주세요.';

  @override
  String unsupportedTimeSignature(String signature) {
    return '지원하지 않는 박자: $signature';
  }

  @override
  String get chooseScoreFile =>
      '지원하지 않는 파일 형식입니다. NWC 또는 NWCTXT 악보 파일만 열 수 있습니다.';

  @override
  String get unreadableFile => '파일을 읽을 수 없거나 너무 큽니다';

  @override
  String get unsupportedParts => '지원하지 않는 파트 구성입니다';

  @override
  String get proInfoFailed => '구매 정보를 불러오지 못했습니다.';

  @override
  String get proBillingUnavailable => 'Google Play 결제를 사용할 수 없습니다.';

  @override
  String get proConnectionError => 'Google Play 연결을 확인해주세요.';

  @override
  String get proInternetRequired => 'Pro 구매를 다시 확인하려면 인터넷 연결이 필요합니다.';

  @override
  String get proConfirmFailed => '구매 확인을 완료하지 못했습니다. 다시 복원해주세요.';

  @override
  String get proStartFailed => 'Google Play 결제를 시작하지 못했습니다.';

  @override
  String get proWindowFailed => '구매 창을 열지 못했습니다.';

  @override
  String get proRestoring => '구매 내역을 확인하고 있습니다.';

  @override
  String get proRestoreFailed => '구매 복원에 실패했습니다.';

  @override
  String get proPending => '결제 승인 대기 중입니다.';

  @override
  String get proIncomplete => '결제가 완료되지 않았습니다.';

  @override
  String get proUnlocked => 'Pro 기능이 열렸습니다.';

  @override
  String get proInvalid => '유효한 Pro 구매를 확인하지 못했습니다.';

  @override
  String get proOffline => '오프라인 인증 기간 동안 Pro를 사용할 수 있습니다.';

  @override
  String get proServerUnavailable => '결제 검증 서버에 연결하지 못했습니다.';

  @override
  String get proRevoked => 'Pro 구매가 취소 또는 환불되어 잠금 상태로 전환됐습니다.';

  @override
  String get proDescription =>
      '악보 보기와 기본 재생은 무료입니다. Pro에서 파트별 볼륨, 피치 조절, 구간 반복, 재생 설정, 악보 도구와 즐겨찾기를 사용할 수 있습니다.';

  @override
  String get proTerms => '일회성 구매 · 오프라인 사용은 마지막 확인 후 최대 7일. 이후 인터넷 연결이 필요합니다.';

  @override
  String get proNotConfigured => '결제 검증 서버가 아직 연결되지 않아 구매를 시작할 수 없습니다.';

  @override
  String buyPro(String price) {
    return 'Pro 영구 잠금 해제 · $price';
  }

  @override
  String get proProductUnavailable =>
      'Google Play에서 현재 이 계정과 기기에 구매 가능한 Pro 상품을 가져오지 못했습니다. 상품 정보를 새로고침해 다시 확인해주세요.';

  @override
  String get proProductLoading => 'Google Play에서 Pro 상품과 가격을 확인하고 있습니다…';

  @override
  String get proProductTimeout =>
      'Google Play 상품 조회 응답이 지연되고 있습니다. 연결을 확인한 뒤 다시 시도해주세요.';

  @override
  String get proRefreshProduct => '상품 정보 새로고침';

  @override
  String get restorePurchases => '구매 복원';

  @override
  String get reviewAccess => '심사용 접근 / Review access';

  @override
  String get reviewDescription =>
      '승인된 앱 심사용입니다. Play Console에 제공된 접근 코드를 입력하세요. 구매나 계정은 필요하지 않으며, 앱을 새로 실행할 때마다 코드 확인을 위해 인터넷 연결이 필요합니다. 동일한 Pro 기능이 열리며 구매가 생성되지는 않습니다.';

  @override
  String get reviewCode => '심사용 접근 코드';

  @override
  String get reviewActivate => '심사용 접근 활성화';

  @override
  String get reviewChecking => '코드 확인 중…';

  @override
  String get reviewActive => '심사용 접근이 활성화되었습니다. 구매 없이 모든 Pro 기능을 사용할 수 있습니다.';

  @override
  String get reviewInvalid => '유효하지 않거나 사용 중지된 심사용 접근 코드입니다.';

  @override
  String get reviewUnavailable =>
      '심사용 접근을 확인하지 못했습니다. 인터넷 연결을 확인하고 다시 시도하세요. 심사용 서버 설정도 완료되어 있어야 합니다.';

  @override
  String get reviewReconnect => '인터넷에 연결하여 심사용 접근을 다시 확인하세요.';

  @override
  String get reviewEnd => '이 기기에서 심사용 접근 종료';

  @override
  String get privacySummary =>
      '악보는 기기 안에서만 처리합니다. Pro 구매 시 구매 토큰과 상품·앱 ID를 검증 서버에 전송합니다. 심사용 접근 기능을 사용하는 경우, 코드를 기기 보안 저장소에 보관하고 동일한 서버로 전송해 확인합니다.\n\n지원 형식: NWC 2.75 / NWCTXT. 구형 바이너리 NWC 1.75·2.5는 PC에서 2.75로 다시 저장하거나 NWCTXT로 변환해주세요.';

  @override
  String get copyPrivacyUrl => '아래 주소를 복사해 브라우저에서 열어주세요.';

  @override
  String get openPrivacy => '개인정보처리방침 열기';

  @override
  String get privacyNotConfigured => '검토용 빌드: 개인정보처리방침 공개 주소 미설정';

  @override
  String get openLicenses => '오픈소스·폰트 라이선스';

  @override
  String get close => '닫기';
}
