// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'nwc_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class NwcLocalizationsEn extends NwcLocalizations {
  NwcLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get scoreFolder => 'Score folder';

  @override
  String get chooseScoreFolder => 'Choose folder';

  @override
  String get changeScoreFolder => 'Change folder';

  @override
  String get folderBack => 'Back';

  @override
  String get folderRefresh => 'Refresh list';

  @override
  String get folderHelp =>
      'Show only NWC/NWCTXT files and subfolders in an allowed folder. You do not need to move your files.';

  @override
  String get folderPermissionHelp =>
      'Choose a folder containing scores and allow access.\n\nOn Android 11 or later, the Download folder itself and storage roots cannot be granted as folders. Use ‘Open file’ above to open individual files there directly. You can choose a subfolder; creating a new folder is not required.';

  @override
  String get folderLoading => 'Reading this folder’s list…';

  @override
  String get folderEmpty => 'No NWC/NWCTXT files or subfolders in this folder.';

  @override
  String get folderAccessError =>
      'Cannot read this folder or file. Access may have been revoked or the file moved. Choose the folder again or use ‘Open file’.';

  @override
  String get folderTimeout =>
      'The storage provider is taking too long. Check your connection, then refresh the list or use ‘Open file’.';

  @override
  String get exitAppTitle => 'Exit app';

  @override
  String get exitAppMessage => 'Exit NWC Player?';

  @override
  String get cancelExit => 'Cancel';

  @override
  String get openFile => 'Open file';

  @override
  String get openNwcFile => 'Open NWC file';

  @override
  String get readingFile => 'Reading file';

  @override
  String get performanceMenu => 'Player controls';

  @override
  String get partVolumes => 'Part volumes';

  @override
  String get pitchAdjustment => 'Pitch (semitones)';

  @override
  String tonic(String note) {
    return 'Tonic: $note';
  }

  @override
  String get originalPitch => 'Reset pitch';

  @override
  String get pitchHelp =>
      'Transpose the score and playback for each key-signature section.\nThe original file is not changed.';

  @override
  String fromBar(int bar) {
    return 'From bar $bar';
  }

  @override
  String barRange(int from, int to) {
    return 'Bars $from–$to';
  }

  @override
  String get lowerPitch => 'Down a semitone';

  @override
  String get raisePitch => 'Up a semitone';

  @override
  String get playback => 'Playback';

  @override
  String get startBar => 'Start bar';

  @override
  String get previousBar => 'Previous bar';

  @override
  String get nextBar => 'Next bar';

  @override
  String get barUnit => 'bar';

  @override
  String get lowerBpm => 'Decrease BPM';

  @override
  String get raiseBpm => 'Increase BPM';

  @override
  String get originalSpeed => 'Reset tempo';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get stop => 'Stop';

  @override
  String get playSelected => 'Play selected';

  @override
  String get playAll => 'Play all';

  @override
  String get repeatSection => 'Loop';

  @override
  String get start => 'Start';

  @override
  String get end => 'End';

  @override
  String get playLoop => 'Play loop';

  @override
  String get score => 'Score';

  @override
  String get scoreSize => 'Score size';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get landscape => 'Landscape';

  @override
  String get closeLandscape => 'Close landscape';

  @override
  String get followScore => 'Follow score';

  @override
  String get selectParts => 'Select parts to display';

  @override
  String get scrollMenu => 'Scroll for more controls';

  @override
  String playingBar(String bar) {
    return 'Playing bar: $bar';
  }

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String get favorites => 'Favorites';

  @override
  String get appInformation => 'About & privacy';

  @override
  String get unlockPro => 'Unlock Pro';

  @override
  String get lockedControl => 'Unlock with Pro';

  @override
  String get exitPlayer => 'Close player';

  @override
  String get favoriteTooLarge =>
      'Files larger than 2 MB cannot be saved as favorites.';

  @override
  String get playbackFinished => 'Playback finished';

  @override
  String get preparingPlayback => 'Preparing playback';

  @override
  String get playing => 'Playing';

  @override
  String get resumedPlayback => 'Playback resumed';

  @override
  String get stoppedPlayback => 'Stopped';

  @override
  String get preparingLoop => 'Preparing loop';

  @override
  String loopStatus(int from, int to) {
    return 'Looping bars $from–$to';
  }

  @override
  String loopTitle(String name, int from, int to) {
    return '$name · Loop bars $from–$to';
  }

  @override
  String playbackProgress(String status, int bar, int bpm) {
    return '$status · Bar $bar · $bpm BPM';
  }

  @override
  String realtimeError(String error) {
    return 'Playback error: $error';
  }

  @override
  String readFailed(String error) {
    return 'Could not open file: $error';
  }

  @override
  String favoriteFailed(String error) {
    return 'Could not open favorite: $error';
  }

  @override
  String playbackFailed(String error) {
    return 'Could not play: $error';
  }

  @override
  String loopFailed(String error) {
    return 'Could not loop: $error';
  }

  @override
  String get unexpectedError =>
      'The operation could not be completed. Check the file and your device, then try again.';

  @override
  String get invalidNwcString => 'Invalid NWC text.';

  @override
  String get emptyOrLargeScore => 'The score is empty or larger than 20 MB.';

  @override
  String get corruptCompressedScore =>
      'The compressed score is damaged or expands beyond 20 MB. Please check the original file.';

  @override
  String get scoreTooLarge =>
      'Please select an NWC or NWCTXT score no larger than 20 MB.';

  @override
  String get invalidScore =>
      'This is not an NWC/NWCTXT score, or the file is damaged.';

  @override
  String get legacyScore =>
      'Older NWC binary files (1.75/2.5) are not supported directly. Open the file in NoteWorthy Composer 2.75 and save it again, or export it as NWCTXT.';

  @override
  String unsupportedTimeSignature(String signature) {
    return 'Unsupported time signature: $signature';
  }

  @override
  String get chooseScoreFile =>
      'Unsupported file type. Only NWC or NWCTXT score files can be opened.';

  @override
  String get unreadableFile => 'The file cannot be read or is too large.';

  @override
  String get unsupportedParts =>
      'Unsupported part configuration (1–16 parts required).';

  @override
  String get proInfoFailed => 'Could not load purchase information.';

  @override
  String get proBillingUnavailable => 'Google Play billing is unavailable.';

  @override
  String get proConnectionError =>
      'Please check your connection to Google Play.';

  @override
  String get proInternetRequired =>
      'Connect to the internet to verify your Pro purchase again.';

  @override
  String get proConfirmFailed =>
      'Could not verify the purchase. Please try restoring it again.';

  @override
  String get proStartFailed => 'Could not start Google Play billing.';

  @override
  String get proWindowFailed => 'Could not open the purchase screen.';

  @override
  String get proRestoring => 'Checking your purchases.';

  @override
  String get proRestoreFailed => 'Could not restore purchases.';

  @override
  String get proPending => 'Your payment is pending.';

  @override
  String get proIncomplete => 'The purchase was not completed.';

  @override
  String get proUnlocked => 'Pro features are unlocked.';

  @override
  String get proInvalid => 'No valid Pro purchase could be verified.';

  @override
  String get proOffline => 'You can use Pro during the offline grace period.';

  @override
  String get proServerUnavailable =>
      'Could not connect to the purchase verification server.';

  @override
  String get proRevoked =>
      'Your Pro purchase was canceled or refunded. Pro features are now locked.';

  @override
  String get proDescription =>
      'Score viewing and basic playback are free. Unlock Pro for part volumes, transposition, looping, playback settings, score tools and favorites.';

  @override
  String get proTerms =>
      'One-time purchase. Use Pro offline for up to 7 days after the last verification, then reconnect to the internet.';

  @override
  String get proNotConfigured =>
      'Purchases are unavailable because the verification server is not connected yet.';

  @override
  String buyPro(String price) {
    return 'Unlock Pro permanently · $price';
  }

  @override
  String get proProductUnavailable =>
      'Google Play did not return a Pro product available for this account and device. Refresh the product information to try again.';

  @override
  String get proProductLoading =>
      'Checking the Pro product and price on Google Play…';

  @override
  String get proProductTimeout =>
      'Google Play took too long to return product information. Check your connection and try again.';

  @override
  String get proRefreshProduct => 'Refresh product information';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get reviewAccess => 'Review access';

  @override
  String get reviewDescription =>
      'For authorized app review only. Enter the access code supplied in Play Console. No purchase or account is needed. Internet is required on each app launch to verify the code. The same Pro features are enabled; this does not create a purchase.';

  @override
  String get reviewCode => 'Review access code';

  @override
  String get reviewActivate => 'Activate review access';

  @override
  String get reviewChecking => 'Verifying code…';

  @override
  String get reviewActive =>
      'Review access active. All Pro features are available without a purchase.';

  @override
  String get reviewInvalid =>
      'This review access code is invalid or has been disabled.';

  @override
  String get reviewUnavailable =>
      'Could not verify review access. Check your internet connection and try again. The review server must also be configured.';

  @override
  String get reviewReconnect =>
      'Connect to the internet to verify review access again.';

  @override
  String get reviewEnd => 'End review access on this device';

  @override
  String get privacySummary =>
      'Scores are processed only on your device. When you purchase Pro, the purchase token, product ID and app ID are sent to the verification server. If you use review access, its code is stored securely on your device and sent to the same server for verification.\n\nSupported formats: NWC 2.75 / NWCTXT. For older NWC 1.75/2.5 binary files, save them again with version 2.75 on a PC or export them as NWCTXT.';

  @override
  String get copyPrivacyUrl =>
      'Copy the address below and open it in your browser.';

  @override
  String get openPrivacy => 'Open privacy policy';

  @override
  String get privacyNotConfigured =>
      'Review build: no public privacy policy URL is configured.';

  @override
  String get openLicenses => 'Open-source & font licenses';

  @override
  String get close => 'Close';
}
