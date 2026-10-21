import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'player_localizations.dart';

const supportedScoreExtensions = ['nwc', 'nwctxt'];
const maxScoreFileBytes = 20 * 1024 * 1024;
const _headerProbeBytes = 512;

bool isSupportedScoreName(String name) =>
    RegExp(r'\.(nwc|nwctxt)$', caseSensitive: false).hasMatch(name);

void validateScoreName(String name) {
  if (!isSupportedScoreName(name)) {
    throw const ScoreReadException(ScoreReadError.wrongExtension);
  }
}

/// Check the beginning, not arbitrary text embedded inside an EXE/ZIP/PDF.
/// The binary signatures also allow old NWC files to reach the conversion hint.
void validateScoreHeader(List<int> bytes) {
  var offset = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf) {
    offset = 3;
  }
  final prefix = ascii.decode(
    bytes.skip(offset).take(_headerProbeBytes).toList(),
    allowInvalid: true,
  );
  if (prefix.startsWith('[NWZ]\x00') ||
      prefix.startsWith('[NoteWorthy ArtWare]') ||
      prefix.startsWith('[NoteWorthy Composer]') ||
      prefix.trimLeft().startsWith('!NoteWorthyComposer(')) {
    return;
  }
  throw const ScoreReadException(ScoreReadError.invalidFile);
}

void validateScoreBytes(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const ScoreReadException(ScoreReadError.emptyOrLarge);
  }
  if (bytes.length > maxScoreFileBytes) {
    throw const ScoreReadException(ScoreReadError.tooLarge);
  }
  validateScoreHeader(bytes);
}

/// Never request eager byte loading: the native picker can run out of memory
/// before Dart sees the selected filename or size. OS/provider filters are only
/// a convenience; validate every returned file even when custom filters exist.
Future<PlatformFile?> pickScoreFile({FilePicker? picker}) async {
  final selection = await (picker ?? FilePicker.platform).pickFiles(
    type: FileType.custom,
    allowedExtensions: supportedScoreExtensions,
    withData: false,
    withReadStream: true,
    allowMultiple: false,
  );
  if (selection == null || selection.files.isEmpty) return null;
  if (selection.files.length != 1) {
    throw const ScoreReadException(ScoreReadError.unreadable);
  }
  return selection.files.single;
}

Future<Uint8List> readScoreFile(PlatformFile file) async {
  // Reject unsupported extensions before subscribing to the stream at all.
  validateScoreName(file.name);
  if (file.size > maxScoreFileBytes) {
    throw const ScoreReadException(ScoreReadError.tooLarge);
  }
  final stream = file.readStream;
  if (stream == null) {
    // Some providers/platforms return bytes despite withData:false.
    final bytes = file.bytes;
    if (bytes == null) {
      throw const ScoreReadException(ScoreReadError.unreadable);
    }
    validateScoreBytes(bytes);
    return bytes;
  }

  final builder = BytesBuilder(copy: false);
  final prefix = <int>[];
  var checkedHeader = false;
  // Metadata can be unknown or inaccurate. Enforce the cap on actual bytes too.
  // await-for cancels its subscription if validation throws.
  await for (final chunk in stream) {
    if (builder.length + chunk.length > maxScoreFileBytes) {
      throw const ScoreReadException(ScoreReadError.tooLarge);
    }
    if (!checkedHeader) {
      prefix.addAll(chunk.take(_headerProbeBytes - prefix.length));
      if (prefix.length == _headerProbeBytes) {
        validateScoreHeader(prefix);
        checkedHeader = true;
      }
    }
    builder.add(chunk);
  }
  final bytes = builder.takeBytes();
  validateScoreBytes(bytes);
  return bytes;
}
