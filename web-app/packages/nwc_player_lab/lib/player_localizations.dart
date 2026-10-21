import 'package:flutter/widgets.dart';
import 'l10n/nwc_localizations.dart';
import 'l10n/nwc_localizations_ko.dart';

export 'l10n/nwc_localizations.dart';

typedef LocalizedText = String Function(NwcLocalizations strings);

/// The first device language decides: Korean -> Korean, anything else -> English.
/// If the platform supplies no language, retain the original Korean default.
Locale resolvePlayerLocale(List<Locale>? locales, Iterable<Locale> supported) {
  if (locales == null || locales.isEmpty) return const Locale('ko');
  return Locale(locales.first.languageCode == 'ko' ? 'ko' : 'en');
}

/// AST embeds the widgets without this app's localization delegate. Keep its
/// existing Korean UI, instead of following the host's default English locale.
NwcLocalizations playerStrings(BuildContext context) =>
    NwcLocalizations.of(context) ?? NwcLocalizationsKo();

enum ScoreReadError {
  invalidString,
  emptyOrLarge,
  corruptCompression,
  tooLarge,
  invalidFile,
  legacyBinary,
  timeSignature,
  wrongExtension,
  unreadable,
  unsupportedParts,
}

/// Carry an error code, not translated text, across the parser/UI boundary.
/// FormatException compatibility and Korean diagnostics are retained for hosts.
class ScoreReadException extends FormatException {
  const ScoreReadException(this.kind, [this.detail = '']);
  final ScoreReadError kind;
  final String detail;

  String localized(NwcLocalizations s) => switch (kind) {
    ScoreReadError.invalidString => s.invalidNwcString,
    ScoreReadError.emptyOrLarge => s.emptyOrLargeScore,
    ScoreReadError.corruptCompression => s.corruptCompressedScore,
    ScoreReadError.tooLarge => s.scoreTooLarge,
    ScoreReadError.invalidFile => s.invalidScore,
    ScoreReadError.legacyBinary => s.legacyScore,
    ScoreReadError.timeSignature => s.unsupportedTimeSignature(detail),
    ScoreReadError.wrongExtension => s.chooseScoreFile,
    ScoreReadError.unreadable => s.unreadableFile,
    ScoreReadError.unsupportedParts => s.unsupportedParts,
  };

  @override
  String get message => localized(NwcLocalizationsKo());

  @override
  String toString() => 'FormatException: $message';
}

String playerErrorText(Object error, NwcLocalizations s) =>
    error is ScoreReadException ? error.localized(s) : s.unexpectedError;
