import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'nwc_localizations_en.dart';
import 'nwc_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of NwcLocalizations
/// returned by `NwcLocalizations.of(context)`.
///
/// Applications need to include `NwcLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/nwc_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: NwcLocalizations.localizationsDelegates,
///   supportedLocales: NwcLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the NwcLocalizations.supportedLocales
/// property.
abstract class NwcLocalizations {
  NwcLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static NwcLocalizations? of(BuildContext context) {
    return Localizations.of<NwcLocalizations>(context, NwcLocalizations);
  }

  static const LocalizationsDelegate<NwcLocalizations> delegate =
      _NwcLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @scoreFolder.
  ///
  /// In ko, this message translates to:
  /// **'악보 폴더'**
  String get scoreFolder;

  /// No description provided for @chooseScoreFolder.
  ///
  /// In ko, this message translates to:
  /// **'폴더 선택'**
  String get chooseScoreFolder;

  /// No description provided for @changeScoreFolder.
  ///
  /// In ko, this message translates to:
  /// **'폴더 변경'**
  String get changeScoreFolder;

  /// No description provided for @folderBack.
  ///
  /// In ko, this message translates to:
  /// **'뒤로'**
  String get folderBack;

  /// No description provided for @folderRefresh.
  ///
  /// In ko, this message translates to:
  /// **'목록 새로고침'**
  String get folderRefresh;

  /// No description provided for @folderHelp.
  ///
  /// In ko, this message translates to:
  /// **'허용한 폴더에서 NWC·NWCTXT 파일과 하위 폴더만 표시합니다. 파일을 옮길 필요는 없습니다.'**
  String get folderHelp;

  /// No description provided for @folderPermissionHelp.
  ///
  /// In ko, this message translates to:
  /// **'먼저 악보가 있는 폴더를 선택하고 접근을 허용해 주세요.\n\nAndroid 11 이상에서는 ‘다운로드’ 폴더 자체나 저장소 루트를 폴더로 허용할 수 없습니다. 그 안의 파일은 위의 ‘파일 열기’로 바로 열 수 있습니다. 하위 폴더는 선택할 수 있으며, 새 폴더를 만들 필요는 없습니다.'**
  String get folderPermissionHelp;

  /// No description provided for @folderLoading.
  ///
  /// In ko, this message translates to:
  /// **'현재 폴더의 목록을 읽는 중…'**
  String get folderLoading;

  /// No description provided for @folderEmpty.
  ///
  /// In ko, this message translates to:
  /// **'이 폴더에는 NWC·NWCTXT 파일이나 하위 폴더가 없습니다.'**
  String get folderEmpty;

  /// No description provided for @folderAccessError.
  ///
  /// In ko, this message translates to:
  /// **'폴더 또는 파일을 읽을 수 없습니다. 접근 권한이 해제되었거나 파일이 이동되었을 수 있습니다. 폴더를 다시 선택하거나 ‘파일 열기’를 이용해 주세요.'**
  String get folderAccessError;

  /// No description provided for @folderTimeout.
  ///
  /// In ko, this message translates to:
  /// **'저장소 응답이 지연되고 있습니다. 연결 상태를 확인한 뒤 목록을 새로고침하거나 ‘파일 열기’를 이용해 주세요.'**
  String get folderTimeout;

  /// No description provided for @exitAppTitle.
  ///
  /// In ko, this message translates to:
  /// **'앱 종료'**
  String get exitAppTitle;

  /// No description provided for @exitAppMessage.
  ///
  /// In ko, this message translates to:
  /// **'NWC Player를 종료할까요?'**
  String get exitAppMessage;

  /// No description provided for @cancelExit.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancelExit;

  /// No description provided for @openFile.
  ///
  /// In ko, this message translates to:
  /// **'파일 열기'**
  String get openFile;

  /// No description provided for @openNwcFile.
  ///
  /// In ko, this message translates to:
  /// **'NWC 파일 열기'**
  String get openNwcFile;

  /// No description provided for @readingFile.
  ///
  /// In ko, this message translates to:
  /// **'파일 읽는 중'**
  String get readingFile;

  /// No description provided for @performanceMenu.
  ///
  /// In ko, this message translates to:
  /// **'연주 메뉴'**
  String get performanceMenu;

  /// No description provided for @partVolumes.
  ///
  /// In ko, this message translates to:
  /// **'파트별 볼륨 조절'**
  String get partVolumes;

  /// No description provided for @pitchAdjustment.
  ///
  /// In ko, this message translates to:
  /// **'피치 조절 (반음)'**
  String get pitchAdjustment;

  /// No description provided for @tonic.
  ///
  /// In ko, this message translates to:
  /// **'으뜸음 : {note}'**
  String tonic(String note);

  /// No description provided for @originalPitch.
  ///
  /// In ko, this message translates to:
  /// **'원음'**
  String get originalPitch;

  /// No description provided for @pitchHelp.
  ///
  /// In ko, this message translates to:
  /// **'조표가 바뀌는 구간별로 악보와 재생음을 함께 조절합니다.\n원본 파일은 변경되지 않습니다.'**
  String get pitchHelp;

  /// No description provided for @fromBar.
  ///
  /// In ko, this message translates to:
  /// **'{bar}마디부터'**
  String fromBar(int bar);

  /// No description provided for @barRange.
  ///
  /// In ko, this message translates to:
  /// **'{from}~{to}마디'**
  String barRange(int from, int to);

  /// No description provided for @lowerPitch.
  ///
  /// In ko, this message translates to:
  /// **'반음 내리기'**
  String get lowerPitch;

  /// No description provided for @raisePitch.
  ///
  /// In ko, this message translates to:
  /// **'반음 올리기'**
  String get raisePitch;

  /// No description provided for @playback.
  ///
  /// In ko, this message translates to:
  /// **'재생'**
  String get playback;

  /// No description provided for @startBar.
  ///
  /// In ko, this message translates to:
  /// **'시작 마디'**
  String get startBar;

  /// No description provided for @previousBar.
  ///
  /// In ko, this message translates to:
  /// **'이전 마디'**
  String get previousBar;

  /// No description provided for @nextBar.
  ///
  /// In ko, this message translates to:
  /// **'다음 마디'**
  String get nextBar;

  /// No description provided for @barUnit.
  ///
  /// In ko, this message translates to:
  /// **'마디'**
  String get barUnit;

  /// No description provided for @lowerBpm.
  ///
  /// In ko, this message translates to:
  /// **'BPM 낮추기'**
  String get lowerBpm;

  /// No description provided for @raiseBpm.
  ///
  /// In ko, this message translates to:
  /// **'BPM 높이기'**
  String get raiseBpm;

  /// No description provided for @originalSpeed.
  ///
  /// In ko, this message translates to:
  /// **'원래 속도'**
  String get originalSpeed;

  /// No description provided for @pause.
  ///
  /// In ko, this message translates to:
  /// **'일시정지'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In ko, this message translates to:
  /// **'재개'**
  String get resume;

  /// No description provided for @stop.
  ///
  /// In ko, this message translates to:
  /// **'정지'**
  String get stop;

  /// No description provided for @playSelected.
  ///
  /// In ko, this message translates to:
  /// **'체크된 파트 재생'**
  String get playSelected;

  /// No description provided for @playAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 재생'**
  String get playAll;

  /// No description provided for @repeatSection.
  ///
  /// In ko, this message translates to:
  /// **'구간 반복'**
  String get repeatSection;

  /// No description provided for @start.
  ///
  /// In ko, this message translates to:
  /// **'시작'**
  String get start;

  /// No description provided for @end.
  ///
  /// In ko, this message translates to:
  /// **'끝'**
  String get end;

  /// No description provided for @playLoop.
  ///
  /// In ko, this message translates to:
  /// **'구간 반복 재생'**
  String get playLoop;

  /// No description provided for @score.
  ///
  /// In ko, this message translates to:
  /// **'악보'**
  String get score;

  /// No description provided for @scoreSize.
  ///
  /// In ko, this message translates to:
  /// **'악보 크기'**
  String get scoreSize;

  /// No description provided for @zoomOut.
  ///
  /// In ko, this message translates to:
  /// **'악보 축소'**
  String get zoomOut;

  /// No description provided for @zoomIn.
  ///
  /// In ko, this message translates to:
  /// **'악보 확대'**
  String get zoomIn;

  /// No description provided for @landscape.
  ///
  /// In ko, this message translates to:
  /// **'가로 보기'**
  String get landscape;

  /// No description provided for @closeLandscape.
  ///
  /// In ko, this message translates to:
  /// **'가로화면 닫기'**
  String get closeLandscape;

  /// No description provided for @followScore.
  ///
  /// In ko, this message translates to:
  /// **'악보 따라가기'**
  String get followScore;

  /// No description provided for @selectParts.
  ///
  /// In ko, this message translates to:
  /// **'표시할 파트를 선택하세요'**
  String get selectParts;

  /// No description provided for @scrollMenu.
  ///
  /// In ko, this message translates to:
  /// **'메뉴는 위아래로 스크롤'**
  String get scrollMenu;

  /// No description provided for @playingBar.
  ///
  /// In ko, this message translates to:
  /// **'재생중인 마디 : {bar}'**
  String playingBar(String bar);

  /// No description provided for @addFavorite.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기 추가'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기 해제'**
  String get removeFavorite;

  /// No description provided for @favorites.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기'**
  String get favorites;

  /// No description provided for @appInformation.
  ///
  /// In ko, this message translates to:
  /// **'앱 정보 및 개인정보처리방침'**
  String get appInformation;

  /// No description provided for @unlockPro.
  ///
  /// In ko, this message translates to:
  /// **'Pro 잠금 해제'**
  String get unlockPro;

  /// No description provided for @lockedControl.
  ///
  /// In ko, this message translates to:
  /// **'Pro에서 사용 · 잠금 해제'**
  String get lockedControl;

  /// No description provided for @exitPlayer.
  ///
  /// In ko, this message translates to:
  /// **'플레이어 종료'**
  String get exitPlayer;

  /// No description provided for @favoriteTooLarge.
  ///
  /// In ko, this message translates to:
  /// **'2MB를 넘는 파일은 즐겨찾기에 저장할 수 없습니다'**
  String get favoriteTooLarge;

  /// No description provided for @playbackFinished.
  ///
  /// In ko, this message translates to:
  /// **'전체 연주 완료'**
  String get playbackFinished;

  /// No description provided for @preparingPlayback.
  ///
  /// In ko, this message translates to:
  /// **'준비 중'**
  String get preparingPlayback;

  /// No description provided for @playing.
  ///
  /// In ko, this message translates to:
  /// **'재생'**
  String get playing;

  /// No description provided for @resumedPlayback.
  ///
  /// In ko, this message translates to:
  /// **'연주 재개'**
  String get resumedPlayback;

  /// No description provided for @stoppedPlayback.
  ///
  /// In ko, this message translates to:
  /// **'정지'**
  String get stoppedPlayback;

  /// No description provided for @preparingLoop.
  ///
  /// In ko, this message translates to:
  /// **'구간 반복 준비 중'**
  String get preparingLoop;

  /// No description provided for @loopStatus.
  ///
  /// In ko, this message translates to:
  /// **'{from}~{to}마디 구간 반복'**
  String loopStatus(int from, int to);

  /// No description provided for @loopTitle.
  ///
  /// In ko, this message translates to:
  /// **'{name} · {from}~{to}마디 반복'**
  String loopTitle(String name, int from, int to);

  /// No description provided for @playbackProgress.
  ///
  /// In ko, this message translates to:
  /// **'{status} · {bar}마디 · {bpm} BPM'**
  String playbackProgress(String status, int bar, int bpm);

  /// No description provided for @realtimeError.
  ///
  /// In ko, this message translates to:
  /// **'실시간 재생 오류: {error}'**
  String realtimeError(String error);

  /// No description provided for @readFailed.
  ///
  /// In ko, this message translates to:
  /// **'읽기 실패: {error}'**
  String readFailed(String error);

  /// No description provided for @favoriteFailed.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기 열기 실패: {error}'**
  String favoriteFailed(String error);

  /// No description provided for @playbackFailed.
  ///
  /// In ko, this message translates to:
  /// **'재생 실패: {error}'**
  String playbackFailed(String error);

  /// No description provided for @loopFailed.
  ///
  /// In ko, this message translates to:
  /// **'구간 반복 실패: {error}'**
  String loopFailed(String error);

  /// No description provided for @unexpectedError.
  ///
  /// In ko, this message translates to:
  /// **'작업을 완료하지 못했습니다. 파일과 기기 상태를 확인하고 다시 시도해주세요.'**
  String get unexpectedError;

  /// No description provided for @invalidNwcString.
  ///
  /// In ko, this message translates to:
  /// **'잘못된 NWC 문자열'**
  String get invalidNwcString;

  /// No description provided for @emptyOrLargeScore.
  ///
  /// In ko, this message translates to:
  /// **'빈 파일이거나 20MB를 넘는 악보입니다.'**
  String get emptyOrLargeScore;

  /// No description provided for @corruptCompressedScore.
  ///
  /// In ko, this message translates to:
  /// **'압축 악보가 손상됐거나 압축 해제 크기가 20MB를 넘습니다. 원본을 확인해주세요.'**
  String get corruptCompressedScore;

  /// No description provided for @scoreTooLarge.
  ///
  /// In ko, this message translates to:
  /// **'20MB 이하의 NWC 또는 NWCTXT 악보 파일을 선택해주세요.'**
  String get scoreTooLarge;

  /// No description provided for @invalidScore.
  ///
  /// In ko, this message translates to:
  /// **'NWC/NWCTXT 악보가 아니거나 파일이 손상되었습니다.'**
  String get invalidScore;

  /// No description provided for @legacyScore.
  ///
  /// In ko, this message translates to:
  /// **'구형 NWC 바이너리(1.75/2.5)는 직접 지원하지 않습니다. NoteWorthy Composer 2.75에서 다시 저장하거나 NWCTXT로 내보낸 뒤 열어 주세요.'**
  String get legacyScore;

  /// No description provided for @unsupportedTimeSignature.
  ///
  /// In ko, this message translates to:
  /// **'지원하지 않는 박자: {signature}'**
  String unsupportedTimeSignature(String signature);

  /// No description provided for @chooseScoreFile.
  ///
  /// In ko, this message translates to:
  /// **'지원하지 않는 파일 형식입니다. NWC 또는 NWCTXT 악보 파일만 열 수 있습니다.'**
  String get chooseScoreFile;

  /// No description provided for @unreadableFile.
  ///
  /// In ko, this message translates to:
  /// **'파일을 읽을 수 없거나 너무 큽니다'**
  String get unreadableFile;

  /// No description provided for @unsupportedParts.
  ///
  /// In ko, this message translates to:
  /// **'지원하지 않는 파트 구성입니다'**
  String get unsupportedParts;

  /// No description provided for @proInfoFailed.
  ///
  /// In ko, this message translates to:
  /// **'구매 정보를 불러오지 못했습니다.'**
  String get proInfoFailed;

  /// No description provided for @proBillingUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'Google Play 결제를 사용할 수 없습니다.'**
  String get proBillingUnavailable;

  /// No description provided for @proConnectionError.
  ///
  /// In ko, this message translates to:
  /// **'Google Play 연결을 확인해주세요.'**
  String get proConnectionError;

  /// No description provided for @proInternetRequired.
  ///
  /// In ko, this message translates to:
  /// **'Pro 구매를 다시 확인하려면 인터넷 연결이 필요합니다.'**
  String get proInternetRequired;

  /// No description provided for @proConfirmFailed.
  ///
  /// In ko, this message translates to:
  /// **'구매 확인을 완료하지 못했습니다. 다시 복원해주세요.'**
  String get proConfirmFailed;

  /// No description provided for @proStartFailed.
  ///
  /// In ko, this message translates to:
  /// **'Google Play 결제를 시작하지 못했습니다.'**
  String get proStartFailed;

  /// No description provided for @proWindowFailed.
  ///
  /// In ko, this message translates to:
  /// **'구매 창을 열지 못했습니다.'**
  String get proWindowFailed;

  /// No description provided for @proRestoring.
  ///
  /// In ko, this message translates to:
  /// **'구매 내역을 확인하고 있습니다.'**
  String get proRestoring;

  /// No description provided for @proRestoreFailed.
  ///
  /// In ko, this message translates to:
  /// **'구매 복원에 실패했습니다.'**
  String get proRestoreFailed;

  /// No description provided for @proPending.
  ///
  /// In ko, this message translates to:
  /// **'결제 승인 대기 중입니다.'**
  String get proPending;

  /// No description provided for @proIncomplete.
  ///
  /// In ko, this message translates to:
  /// **'결제가 완료되지 않았습니다.'**
  String get proIncomplete;

  /// No description provided for @proUnlocked.
  ///
  /// In ko, this message translates to:
  /// **'Pro 기능이 열렸습니다.'**
  String get proUnlocked;

  /// No description provided for @proInvalid.
  ///
  /// In ko, this message translates to:
  /// **'유효한 Pro 구매를 확인하지 못했습니다.'**
  String get proInvalid;

  /// No description provided for @proOffline.
  ///
  /// In ko, this message translates to:
  /// **'오프라인 인증 기간 동안 Pro를 사용할 수 있습니다.'**
  String get proOffline;

  /// No description provided for @proServerUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'결제 검증 서버에 연결하지 못했습니다.'**
  String get proServerUnavailable;

  /// No description provided for @proRevoked.
  ///
  /// In ko, this message translates to:
  /// **'Pro 구매가 취소 또는 환불되어 잠금 상태로 전환됐습니다.'**
  String get proRevoked;

  /// No description provided for @proDescription.
  ///
  /// In ko, this message translates to:
  /// **'악보 보기와 기본 재생은 무료입니다. Pro에서 파트별 볼륨, 피치 조절, 구간 반복, 재생 설정, 악보 도구와 즐겨찾기를 사용할 수 있습니다.'**
  String get proDescription;

  /// No description provided for @proTerms.
  ///
  /// In ko, this message translates to:
  /// **'일회성 구매 · 오프라인 사용은 마지막 확인 후 최대 7일. 이후 인터넷 연결이 필요합니다.'**
  String get proTerms;

  /// No description provided for @proNotConfigured.
  ///
  /// In ko, this message translates to:
  /// **'결제 검증 서버가 아직 연결되지 않아 구매를 시작할 수 없습니다.'**
  String get proNotConfigured;

  /// No description provided for @buyPro.
  ///
  /// In ko, this message translates to:
  /// **'Pro 영구 잠금 해제 · {price}'**
  String buyPro(String price);

  /// No description provided for @proProductUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'Google Play에서 현재 이 계정과 기기에 구매 가능한 Pro 상품을 가져오지 못했습니다. 상품 정보를 새로고침해 다시 확인해주세요.'**
  String get proProductUnavailable;

  /// No description provided for @proProductLoading.
  ///
  /// In ko, this message translates to:
  /// **'Google Play에서 Pro 상품과 가격을 확인하고 있습니다…'**
  String get proProductLoading;

  /// No description provided for @proProductTimeout.
  ///
  /// In ko, this message translates to:
  /// **'Google Play 상품 조회 응답이 지연되고 있습니다. 연결을 확인한 뒤 다시 시도해주세요.'**
  String get proProductTimeout;

  /// No description provided for @proRefreshProduct.
  ///
  /// In ko, this message translates to:
  /// **'상품 정보 새로고침'**
  String get proRefreshProduct;

  /// No description provided for @restorePurchases.
  ///
  /// In ko, this message translates to:
  /// **'구매 복원'**
  String get restorePurchases;

  /// No description provided for @reviewAccess.
  ///
  /// In ko, this message translates to:
  /// **'심사용 접근 / Review access'**
  String get reviewAccess;

  /// No description provided for @reviewDescription.
  ///
  /// In ko, this message translates to:
  /// **'승인된 앱 심사용입니다. Play Console에 제공된 접근 코드를 입력하세요. 구매나 계정은 필요하지 않으며, 앱을 새로 실행할 때마다 코드 확인을 위해 인터넷 연결이 필요합니다. 동일한 Pro 기능이 열리며 구매가 생성되지는 않습니다.'**
  String get reviewDescription;

  /// No description provided for @reviewCode.
  ///
  /// In ko, this message translates to:
  /// **'심사용 접근 코드'**
  String get reviewCode;

  /// No description provided for @reviewActivate.
  ///
  /// In ko, this message translates to:
  /// **'심사용 접근 활성화'**
  String get reviewActivate;

  /// No description provided for @reviewChecking.
  ///
  /// In ko, this message translates to:
  /// **'코드 확인 중…'**
  String get reviewChecking;

  /// No description provided for @reviewActive.
  ///
  /// In ko, this message translates to:
  /// **'심사용 접근이 활성화되었습니다. 구매 없이 모든 Pro 기능을 사용할 수 있습니다.'**
  String get reviewActive;

  /// No description provided for @reviewInvalid.
  ///
  /// In ko, this message translates to:
  /// **'유효하지 않거나 사용 중지된 심사용 접근 코드입니다.'**
  String get reviewInvalid;

  /// No description provided for @reviewUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'심사용 접근을 확인하지 못했습니다. 인터넷 연결을 확인하고 다시 시도하세요. 심사용 서버 설정도 완료되어 있어야 합니다.'**
  String get reviewUnavailable;

  /// No description provided for @reviewReconnect.
  ///
  /// In ko, this message translates to:
  /// **'인터넷에 연결하여 심사용 접근을 다시 확인하세요.'**
  String get reviewReconnect;

  /// No description provided for @reviewEnd.
  ///
  /// In ko, this message translates to:
  /// **'이 기기에서 심사용 접근 종료'**
  String get reviewEnd;

  /// No description provided for @privacySummary.
  ///
  /// In ko, this message translates to:
  /// **'악보는 기기 안에서만 처리합니다. Pro 구매 시 구매 토큰과 상품·앱 ID를 검증 서버에 전송합니다. 심사용 접근 기능을 사용하는 경우, 코드를 기기 보안 저장소에 보관하고 동일한 서버로 전송해 확인합니다.\n\n지원 형식: NWC 2.75 / NWCTXT. 구형 바이너리 NWC 1.75·2.5는 PC에서 2.75로 다시 저장하거나 NWCTXT로 변환해주세요.'**
  String get privacySummary;

  /// No description provided for @copyPrivacyUrl.
  ///
  /// In ko, this message translates to:
  /// **'아래 주소를 복사해 브라우저에서 열어주세요.'**
  String get copyPrivacyUrl;

  /// No description provided for @openPrivacy.
  ///
  /// In ko, this message translates to:
  /// **'개인정보처리방침 열기'**
  String get openPrivacy;

  /// No description provided for @privacyNotConfigured.
  ///
  /// In ko, this message translates to:
  /// **'검토용 빌드: 개인정보처리방침 공개 주소 미설정'**
  String get privacyNotConfigured;

  /// No description provided for @openLicenses.
  ///
  /// In ko, this message translates to:
  /// **'오픈소스·폰트 라이선스'**
  String get openLicenses;

  /// No description provided for @close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get close;
}

class _NwcLocalizationsDelegate
    extends LocalizationsDelegate<NwcLocalizations> {
  const _NwcLocalizationsDelegate();

  @override
  Future<NwcLocalizations> load(Locale locale) {
    return SynchronousFuture<NwcLocalizations>(lookupNwcLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_NwcLocalizationsDelegate old) => false;
}

NwcLocalizations lookupNwcLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return NwcLocalizationsEn();
    case 'ko':
      return NwcLocalizationsKo();
  }

  throw FlutterError(
    'NwcLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
