import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'score_painter.dart';
import 'live_player.dart';
import 'tempo_map.dart';
import 'vip_license.dart';
import 'pro_access.dart';
import 'app_information.dart';
import 'player_localizations.dart';
import 'score_file_input.dart';
import 'score_folder_browser.dart';

export 'score_file_input.dart' show isSupportedScoreName;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledLicenses();
  runApp(const NwcPlayerApp());
}

/// Shared code; only the standalone General/Pro app follows device language.
/// VIP remains Korean until its next separately requested localization update.
class NwcPlayerApp extends StatelessWidget {
  const NwcPlayerApp({super.key, this.home, this.vip = appFlavor == 'vip'});
  final Widget? home;
  final bool vip;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: vip ? 'NWC Player VIP' : 'NWC Player',
    locale: vip ? const Locale('ko') : null,
    supportedLocales: NwcLocalizations.supportedLocales,
    localizationsDelegates: NwcLocalizations.localizationsDelegates,
    localeListResolutionCallback: resolvePlayerLocale,
    home:
        home ??
        (vip
            ? VipLicenseGate(
              builder: (licensedTo) => Lab(vipLicensedTo: licensedTo),
            )
            : const Lab()),
  );
}

bool requiresProAccess({required bool embedded, String? flavor}) =>
    !embedded && flavor != 'vip';

// Diatonic pitch of the middle staff line (C0 = 0).
int clefMiddlePitch(String clef) => switch (clef) {
  'Bass' => 22, // D3
  'Alto' => 28, // C4
  'Tenor' => 26, // A3: the C-clef is on line four
  _ => 34, // B4, treble (percussion retains the existing mapping)
};

class LauncherIconController {
  static const _channel = MethodChannel('nwc/launcher_icon');

  static Future<void> setPro(bool enabled) async {
    if (appFlavor != 'general') return;
    try {
      await _channel.invokeMethod<void>('setPro', {'enabled': enabled});
    } on MissingPluginException {
      // Desktop/web previews do not provide an Android launcher.
    } on PlatformException {
      // Icon switching must never prevent the player from opening.
    }
  }
}

class Note {
  Note(this.beat, this.duration, this.pitch, this.pos);
  final double beat, duration;
  int pitch;
  final int pos;
  String dur = '', opts = '', lyric = '', accidental = '';
  final lyricLines = <int, String>{};
  bool tie = false;
  Note? tieTo, slurTo;
  bool receivesTie = false;
  String head = '';
  int stemGroup = 0;
  bool get grace => dur.contains('Grace');
  bool get muted => opts.split(',').contains('Muted');
}

class ScoreText {
  ScoreText(
    this.beat,
    this.value,
    this.pos,
    this.font, {
    this.rightAligned = false,
  });
  final bool rightAligned;
  final double beat;
  final String value, font;
  final int pos;
}

class Part {
  Part(this.name);
  final String name;
  final notes = <Note>[];
  double length = 0;
  String label = '', clef = 'Treble', octave = '', lyrics = '';
  final verses = <int, String>{};
  final rests = <Note>[];
  final barStyles = <double, String>{};
  final texts = <ScoreText>[];
  String keySignature = '';
  String timeSignature = 'Common';
  final keyChanges = <double, String>{};
  final tempoChanges = <double, double>{};
  final tempoUnits = <double, String>{};
  final fermataPauses = <double, double>{};
  double tempoUnitAt(double beat) {
    var base = 'Quarter';
    for (final e in tempoUnits.entries) {
      if (e.key <= beat) base = e.value;
    }
    return tempoUnitLength(base);
  }

  String tempoSymbolAt(double beat) {
    var base = 'Quarter';
    for (final e in tempoUnits.entries) {
      if (e.key <= beat) base = e.value;
    }
    return {
          'Eighth': '♪',
          'Half': '𝅗𝅥',
          'Half Dotted': '𝅗𝅥.',
          'Quarter Dotted': '♩.',
          'Eighth Dotted': '♪.',
        }[base] ??
        '♩';
  }

  final clefChanges = <double, String>{};
  final octaveChanges = <double, String>{};
  String octaveAt(double beat) {
    var result = octaveChanges.isEmpty ? octave : '';
    for (final change in octaveChanges.entries) {
      if (change.key <= beat) result = change.value;
    }
    return result;
  }

  final dynamics = <double, int>{};
  final endings = <double, String>{};
  final flowChanges = <double, List<String>>{};
  // Boundary collapse is a print-layout hint; continuous editor view keeps rests.
  final boundaryChanges = <double, String>{};
  final instrumentChanges = <double, int>{};
  final spacers = <(double, double)>[];
  final barStarts = <double>[0];
  final timeChanges = <double, String>{};
  double beatAtBar(int index) =>
      index < barStarts.length
          ? barStarts[max(0, index)]
          : barStarts.last + (index - barStarts.length + 1) * 4;
  double displayBeat(double beat) {
    var bar = 0;
    while (bar + 1 < barStarts.length && barStarts[bar + 1] <= beat + .000001) {
      bar++;
    }
    final length = beatAtBar(bar + 1) - beatAtBar(bar);
    return bar * 4 + (beat - beatAtBar(bar)) * 4 / (length > 0 ? length : 4);
  }

  String clefAt(double beat) {
    var result = clefChanges.isEmpty ? clef : 'Treble';
    for (final change in clefChanges.entries) {
      if (change.key <= beat) result = change.value;
    }
    return result;
  }

  String keyAt(double beat) {
    var signature = '';
    for (final entry in keyChanges.entries) {
      if (entry.key <= beat) signature = entry.value;
    }
    return signature;
  }
}

double tempoUnitLength(String base) =>
    {
      'Whole': 4.0,
      'Half': 2.0,
      'Quarter': 1.0,
      'Eighth': .5,
      'Sixteenth': .25,
      'Half Dotted': 3.0,
      'Quarter Dotted': 1.5,
      'Eighth Dotted': .75,
    }[base] ??
    1.0;

Part displayScore(Part source) {
  final p =
      Part(source.name)
        ..label = source.label
        ..clef = source.clef
        ..octave = source.octave
        ..timeSignature = source.timeSignature
        ..length = source.displayBeat(source.length);
  final copies = <Note, Note>{};
  Note copy(Note n) {
    final note =
        Note(
            source.displayBeat(n.beat),
            source.displayBeat(n.beat + n.duration) -
                source.displayBeat(n.beat),
            n.pitch,
            n.pos,
          )
          ..dur = n.dur
          ..opts = n.opts
          ..lyric = n.lyric
          ..accidental = n.accidental
          ..tie = n.tie
          ..head = n.head
          ..stemGroup = n.stemGroup
          ..receivesTie = n.receivesTie;
    copies[n] = note;
    note.lyricLines.addAll(n.lyricLines);
    return note;
  }

  p.notes.addAll(source.notes.map(copy));
  p.rests.addAll(source.rests.map(copy));
  for (final n in source.notes) {
    copies[n]!.tieTo = copies[n.tieTo];
    copies[n]!.slurTo = copies[n.slurTo];
  }
  for (final t in source.texts) {
    p.texts.add(
      ScoreText(
        source.displayBeat(t.beat),
        t.value,
        t.pos,
        t.font,
        rightAligned: t.rightAligned,
      ),
    );
  }
  for (final pair in [
    (source.keyChanges, p.keyChanges),
    (source.clefChanges, p.clefChanges),
    (source.octaveChanges, p.octaveChanges),
    (source.barStyles, p.barStyles),
    (source.endings, p.endings),
    (source.boundaryChanges, p.boundaryChanges),
    (source.timeChanges, p.timeChanges),
  ]) {
    for (final e in pair.$1.entries) {
      pair.$2[source.displayBeat(e.key)] = e.value;
    }
  }
  for (final e in source.tempoChanges.entries) {
    p.tempoChanges[source.displayBeat(e.key)] = e.value;
  }
  for (final e in source.tempoUnits.entries) {
    p.tempoUnits[source.displayBeat(e.key)] = e.value;
  }
  for (final e in source.fermataPauses.entries) {
    p.fermataPauses[source.displayBeat(e.key)] = e.value;
  }
  for (final e in source.instrumentChanges.entries) {
    p.instrumentChanges[source.displayBeat(e.key)] = e.value;
  }
  for (final spacer in source.spacers) {
    p.spacers.add((source.displayBeat(spacer.$1), spacer.$2));
  }
  return p;
}

const _naturalPitchClasses = [0, 2, 4, 5, 7, 9, 11];
const _sharpOrder = ['F', 'C', 'G', 'D', 'A', 'E', 'B'];
const _flatOrder = ['B', 'E', 'A', 'D', 'G', 'C', 'F'];
const _letterDegrees = {'C': 0, 'D': 1, 'E': 2, 'F': 3, 'G': 4, 'A': 5, 'B': 6};

int _signatureFifths(String signature) {
  final tokens = signature.split(',').where((e) => e.length == 2).toList();
  if (tokens.isEmpty) return 0;
  return tokens.first.endsWith('b') ? -tokens.length : tokens.length;
}

String transposeSignature(String signature, int semitones) {
  if (semitones == 0) return signature;
  final fifths = _signatureFifths(signature);
  final sourceTonic = ((fifths * 7) % 12 + 12) % 12;
  final target = (sourceTonic + semitones) % 12;
  final choices = [
    for (var f = -7; f <= 7; f++)
      if (((f * 7) % 12 + 12) % 12 == target) f,
  ]..sort((a, b) {
    final complexity = a.abs().compareTo(b.abs());
    if (complexity != 0) return complexity;
    if (fifths < 0) return a.compareTo(b);
    return b.compareTo(a);
  });
  final next = choices.first;
  final order = next < 0 ? _flatOrder : _sharpOrder;
  final accidental = next < 0 ? 'b' : '#';
  return [
    for (var i = 0; i < next.abs(); i++) '${order[i]}$accidental',
  ].join(',');
}

String signatureTonic(String signature) {
  final fifths = _signatureFifths(signature).clamp(-7, 7);
  const names = <int, String>{
    -7: 'Cb',
    -6: 'Gb',
    -5: 'Db',
    -4: 'Ab',
    -3: 'Eb',
    -2: 'Bb',
    -1: 'F',
    0: 'C',
    1: 'G',
    2: 'D',
    3: 'A',
    4: 'E',
    5: 'B',
    6: 'F#',
    7: 'C#',
  };
  return names[fifths] ?? 'C';
}

String pitchPipeTonic(String tonic) => switch (tonic) {
  'Cb' => 'Cb (B)',
  'Gb' => 'Gb (F#)',
  'Db' => 'Db (C#)',
  'Ab' => 'Ab (G#)',
  'Eb' => 'Eb (D#)',
  'Bb' => 'Bb (A#)',
  _ => tonic,
};

Map<int, int> _keyAlterations(String signature) {
  final result = <int, int>{};
  for (final token in signature.split(',')) {
    if (token.length != 2) continue;
    final degree = _letterDegrees[token[0]];
    if (degree != null) result[degree] = token[1] == '#' ? 1 : -1;
  }
  return result;
}

/// Creates a display/playback copy. The imported NWC objects are never changed.
Part transposePart(Part source, Map<double, int> shifts) {
  int shiftAt(double beat) {
    var value = 0;
    for (final entry in shifts.entries) {
      if (entry.key <= beat + .000001) value = entry.value;
    }
    return value;
  }

  final p =
      Part(source.name)
        ..label = source.label
        ..clef = source.clef
        ..octave = source.octave
        ..lyrics = source.lyrics
        ..keySignature = source.keySignature
        ..timeSignature = source.timeSignature
        ..length = source.length;
  p.verses.addAll(source.verses);
  for (final pair in [
    (source.barStyles, p.barStyles),
    (source.tempoChanges, p.tempoChanges),
    (source.tempoUnits, p.tempoUnits),
    (source.fermataPauses, p.fermataPauses),
    (source.dynamics, p.dynamics),
    (source.endings, p.endings),
    (source.boundaryChanges, p.boundaryChanges),
    (source.instrumentChanges, p.instrumentChanges),
    (source.timeChanges, p.timeChanges),
  ]) {
    pair.$2.addAll(pair.$1);
  }
  p.clefChanges.addAll(source.clefChanges);
  p.octaveChanges.addAll(source.octaveChanges);
  p.flowChanges.addAll(
    source.flowChanges.map((k, v) => MapEntry(k, List.of(v))),
  );
  p.spacers.addAll(source.spacers);
  p.barStarts
    ..clear()
    ..addAll(source.barStarts);
  p.texts.addAll(
    source.texts.map(
      (t) => ScoreText(
        t.beat,
        t.value,
        t.pos,
        t.font,
        rightAligned: t.rightAligned,
      ),
    ),
  );

  final boundaries =
      <double>{...source.keyChanges.keys, ...shifts.keys}.toList()..sort();
  for (final beat in boundaries) {
    p.keyChanges[beat] = transposeSignature(source.keyAt(beat), shiftAt(beat));
  }
  if (p.keyChanges.isEmpty) {
    p.keyChanges[0] = transposeSignature('', shiftAt(0));
  }
  p.keySignature = p.keyChanges.values.first;

  final copies = <Note, Note>{};
  final renderedAccidentals = <int, int>{};
  var accidentalBar = -1;
  var accidentalSignature = '';
  Note copyNote(Note n, {bool rest = false}) {
    if (rest) {
      final result =
          Note(n.beat, n.duration, n.pitch, n.pos)
            ..dur = n.dur
            ..opts = n.opts;
      return result;
    }
    final shift = shiftAt(n.beat);
    var noteBar = 0;
    while (noteBar + 1 < source.barStarts.length &&
        source.barStarts[noteBar + 1] <= n.beat + .000001) {
      noteBar++;
    }
    final signature = transposeSignature(source.keyAt(n.beat), shift);
    if (noteBar != accidentalBar || signature != accidentalSignature) {
      renderedAccidentals.clear();
      accidentalBar = noteBar;
      accidentalSignature = signature;
    }
    if (shift == 0) {
      final result =
          Note(n.beat, n.duration, n.pitch, n.pos)
            ..dur = n.dur
            ..opts = n.opts
            ..lyric = n.lyric
            ..accidental = n.accidental
            ..tie = n.tie
            ..head = n.head
            ..stemGroup = n.stemGroup
            ..receivesTie = n.receivesTie;
      result.lyricLines.addAll(n.lyricLines);
      copies[n] = result;
      return result;
    }
    final targetPitch = n.pitch + shift;
    final clefBase = clefMiddlePitch(source.clefAt(n.beat));
    final oldAbsolute = clefBase + n.pos;
    final expectedAbsolute = oldAbsolute + (shift * 7 / 12).round();
    final key = _keyAlterations(signature);
    var bestAbsolute = expectedAbsolute;
    var bestAccidental = 9;
    var bestCost = 999;
    for (
      var absolute = expectedAbsolute - 4;
      absolute <= expectedAbsolute + 4;
      absolute++
    ) {
      final degree = ((absolute % 7) + 7) % 7;
      final natural =
          12 +
          (absolute ~/ 7) * 12 +
          _naturalPitchClasses[degree] +
          (source.octaveAt(n.beat).contains('Down')
              ? -12
              : source.octaveAt(n.beat).contains('Up')
              ? 12
              : 0);
      final accidental = targetPitch - natural;
      if (accidental < -2 || accidental > 2) continue;
      final cost =
          (absolute - expectedAbsolute).abs() * 3 +
          accidental.abs() +
          (accidental == (key[degree] ?? 0) ? -2 : 0);
      if (cost < bestCost) {
        bestCost = cost;
        bestAbsolute = absolute;
        bestAccidental = accidental;
      }
    }
    final degree = ((bestAbsolute % 7) + 7) % 7;
    final keyAccidental = key[degree] ?? 0;
    final previousAccidental =
        renderedAccidentals[bestAbsolute] ?? keyAccidental;
    final mark =
        n.receivesTie || bestAccidental == previousAccidental
            ? ''
            : bestAccidental == 0
            ? 'n'
            : bestAccidental == 1
            ? '#'
            : bestAccidental == -1
            ? 'b'
            : bestAccidental == 2
            ? 'x'
            : 'v';
    renderedAccidentals[bestAbsolute] = bestAccidental;
    final result =
        Note(n.beat, n.duration, targetPitch, bestAbsolute - clefBase)
          ..dur = n.dur
          ..opts = n.opts
          ..lyric = n.lyric
          ..accidental = mark
          ..tie = n.tie
          ..head = n.head
          ..stemGroup = n.stemGroup
          ..receivesTie = n.receivesTie;
    result.lyricLines.addAll(n.lyricLines);
    copies[n] = result;
    return result;
  }

  p.notes.addAll(source.notes.map(copyNote));
  p.rests.addAll(source.rests.map((n) => copyNote(n, rest: true)));
  for (final n in source.notes) {
    copies[n]!.tieTo = copies[n.tieTo];
    copies[n]!.slurTo = copies[n.slurTo];
  }
  return p;
}

String nwcString(String value) {
  if (!value.startsWith('"') || !value.endsWith('"')) return value;
  final result = StringBuffer();
  for (var i = 1; i < value.length - 1; i++) {
    if (value[i] != r'\') {
      result.write(value[i]);
      continue;
    }
    if (++i >= value.length - 1) {
      throw const ScoreReadException(ScoreReadError.invalidString);
    }
    result.write(
      {
            'n': '\n',
            'r': '\r',
            't': '\t',
            "'": "'",
            '"': '"',
            r'\': r'\',
          }[value[i]] ??
          r'\' + value[i],
    );
  }
  return result.toString();
}

List<String> lyricSyllables(String lyrics) {
  final result = <String>[];
  for (final word in lyrics.trim().split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    if (RegExp(r'^-+$').hasMatch(word)) {
      result.addAll(word.split(''));
      continue;
    }
    final fragments = word.split('-');
    for (var i = 0; i < fragments.length; i++) {
      if (fragments[i].isNotEmpty) {
        result.add(fragments[i] + (i < fragments.length - 1 ? '-' : ''));
      }
    }
  }
  return result;
}

double noteDuration(String dur) {
  var length =
      {
        'Whole': 4.0,
        'Half': 2.0,
        '4th': 1.0,
        '8th': .5,
        '16th': .25,
        '32nd': .125,
        '64th': .0625,
      }[dur.split(',').first] ??
      1.0;
  if (dur.contains('DblDotted')) {
    length *= 1.75;
  } else if (dur.contains('Dotted')) {
    length *= 1.5;
  }
  if (dur.contains('Triplet')) length *= 2 / 3;
  return length;
}

String decodeNwc(Uint8List bytes) {
  validateScoreBytes(bytes);
  final compressed =
      bytes.length >= 5 &&
      ascii.decode(bytes.take(5).toList(), allowInvalid: true) == '[NWZ]';
  if (!compressed) return utf8.decode(bytes, allowMalformed: true);
  try {
    if (bytes.length < 12 || bytes[5] != 0) throw const FormatException();
    final cmf = bytes[6], flg = bytes[7];
    if ((cmf & 15) != 8 ||
        (cmf >> 4) > 7 ||
        ((cmf << 8) + flg) % 31 != 0 ||
        (flg & 32) != 0) {
      throw const FormatException();
    }
    final output = _BoundedScoreOutput();
    // Both zlib wrappers buffer output internally. Bind the inflate output
    // directly so oversized expansion is rejected while it is being decoded.
    final input = InputMemoryStream(
      bytes.sublist(8),
      byteOrder: ByteOrder.bigEndian,
    );
    Inflate.stream(input, output: output);
    if (input.length < 4) throw const FormatException();
    final expected = input.readUint32();
    if (getAdler32(output.getBytes()) != expected) {
      throw const FormatException();
    }
    validateScoreHeader(output.getBytes());
    return utf8.decode(output.getBytes(), allowMalformed: true);
  } catch (_) {
    throw const ScoreReadException(ScoreReadError.corruptCompression);
  }
}

class _BoundedScoreOutput extends OutputMemoryStream {
  void check(int count) {
    if (length + count > maxScoreFileBytes) {
      throw const ScoreReadException(ScoreReadError.tooLarge);
    }
  }

  @override
  void writeByte(int value) {
    check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    check(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    check(count);
    super.writeBackReference(distance, count);
  }
}

List<Part> parse(Uint8List bytes) {
  final text = decodeNwc(bytes);
  if (!text.contains('!NoteWorthyComposer(')) {
    if (!text.contains('[NoteWorthy Composer]') &&
        !text.contains('[NoteWorthy ArtWare]')) {
      throw const ScoreReadException(ScoreReadError.invalidFile);
    }
    throw const ScoreReadException(ScoreReadError.legacyBinary);
  }
  final parts = <Part>[];
  Part? part;
  var clef = 'Treble';
  var meter = 4.0;
  var transpose = 0;
  final accidental = <int, int>{};
  final keyAccidental = <int, int>{};
  for (final line in text.split('\n')) {
    String field(String key) =>
        RegExp(
          r'\|' + RegExp.escape(key) + r':("(?:\\.|[^"\\])*"|[^|\r]*)',
        ).firstMatch(line)?.group(1) ??
        '';
    if (line.startsWith('|AddStaff')) {
      part = Part(nwcString(field('Name')));
      parts.add(part);
      part.label = nwcString(field('Label'));
      clef = 'Treble';
      meter = 4;
      transpose = 0;
      accidental.clear();
      keyAccidental.clear();
    }
    if (part == null) continue;
    if (line.startsWith('|TimeSig|')) {
      final signature = field('Signature');
      final match = RegExp(r'^(\d+)/(\d+)$').firstMatch(signature);
      if (signature == 'Common' || signature == 'AllaBreve') {
        meter = 4;
      } else if (match != null && int.parse(match[2]!) > 0) {
        meter = int.parse(match[1]!) * 4 / int.parse(match[2]!);
      } else {
        throw ScoreReadException(ScoreReadError.timeSignature, signature);
      }
      if (part.timeChanges.isEmpty) part.timeSignature = signature;
      part.timeChanges[part.length] = signature;
    }
    if (line.startsWith('|Tempo|')) {
      final value = double.tryParse(field('Tempo'));
      final base = field('Base').isEmpty ? 'Quarter' : field('Base');
      if (value != null && value > 0) {
        part.tempoChanges[part.length] = value * tempoUnitLength(base);
        part.tempoUnits[part.length] = base;
      }
    }
    if (line.startsWith('|Clef')) {
      clef = field('Type');
      if (part.clefChanges.isEmpty) part.clef = clef;
      part.clefChanges[part.length] = clef;
      if (part.octaveChanges.isEmpty) part.octave = field('OctaveShift');
      part.octaveChanges[part.length] = field('OctaveShift');
    }
    final lyricCommand = RegExp(r'^\|Lyric(\d+)\|').firstMatch(line);
    if (lyricCommand != null) {
      try {
        final number = int.parse(lyricCommand[1]!);
        part.verses[number] = nwcString(field('Text'));
        if (number == 1) part.lyrics = part.verses[number]!;
      } catch (_) {}
    }
    if (line.startsWith('|Ending|')) {
      part.endings[part.length] = field('Endings');
    }
    if (line.startsWith('|Boundary|')) {
      part.boundaryChanges[part.length] = field('Style');
    }
    if (line.startsWith('|Spacer|')) {
      part.spacers.add((part.length, double.tryParse(field('Width')) ?? 0));
    }
    if (line.startsWith('|Instrument|') ||
        line.startsWith('|StaffInstrument|')) {
      transpose = int.tryParse(field('Trans')) ?? 0;
      part.instrumentChanges[part.length] = int.tryParse(field('Patch')) ?? 0;
      if (line.startsWith('|Instrument|') && field('Name').isNotEmpty) {
        part.texts.add(
          ScoreText(
            part.length,
            nwcString(field('Name')),
            int.tryParse(field('Pos')) ?? 0,
            'Regular',
          ),
        );
      }
    }
    if (line.startsWith('|Flow|')) {
      final style = field('Style');
      part.flowChanges.putIfAbsent(part.length, () => <String>[]).add(style);
      part.texts.add(
        ScoreText(
          part.length,
          {
                'Segno': '𝄋',
                'Coda': '𝄌',
                'ToCoda': 'To Coda 𝄌',
                'DSalCoda': 'D.S. al Coda',
                'DalSegno': 'D.S. 𝄋',
                'DSalFine': 'D.S. al Fine',
                'DCalCoda': 'D.C. al Coda',
                'DCalFine': 'D.C. al Fine',
                'Fine': 'Fine',
              }[style] ??
              style,
          int.tryParse(field('Pos')) ?? 9,
          'Italic',
          rightAligned: field('Justify') == 'Right',
        ),
      );
    }
    if (line.startsWith('|TempoVariance|')) {
      final style = field('Style');
      final pause = double.tryParse(field('Pause')) ?? 0;
      if (style == 'Fermata' && pause > 0) {
        part.fermataPauses[part.length] = pause;
      }
      part.texts.add(
        ScoreText(
          part.length,
          {
                'Ritardando': 'ritard.',
                'Ritenuto': 'riten.',
                'Accelerando': 'accel.',
                'Fermata': '𝄐',
              }[style] ??
              style,
          int.tryParse(field('Pos')) ?? 9,
          'Italic',
        ),
      );
    }
    if (line.startsWith('|Dynamic|') || line.startsWith('|DynamicVariance|')) {
      final style = field('Style');
      final value =
          {
            'ppp': 35,
            'pp': 48,
            'p': 62,
            'mp': 78,
            'mf': 94,
            'f': 110,
            'ff': 120,
            'fff': 127,
          }[style];
      if (value != null) part.dynamics[part.length] = value;
      part.texts.add(
        ScoreText(
          part.length,
          {'Crescendo': 'cresc.', 'Decrescendo': 'decresc.'}[style] ?? style,
          int.tryParse(field('Pos')) ?? 9,
          'Italic',
        ),
      );
    }
    if (line.startsWith('|Key|')) {
      part.keySignature = field('Signature');
      part.keyChanges[part.length] = part.keySignature;
      keyAccidental.clear();
      for (final token in part.keySignature.split(',')) {
        final match = RegExp(r'^([A-G])([#b])$').firstMatch(token);
        if (match != null) {
          keyAccidental[{
                'C': 0,
                'D': 1,
                'E': 2,
                'F': 3,
                'G': 4,
                'A': 5,
                'B': 6,
              }[match.group(1)]!] =
              match.group(2) == '#' ? 1 : -1;
        }
      }
    }
    if (line.startsWith('|Bar')) {
      if (part.length > part.barStarts.last + .000001) {
        part.barStarts.add(part.length);
      }
      accidental.clear();
      if (field('Style').isNotEmpty) {
        part.barStyles[part.length] = field('Style');
      }
    }
    if (line.startsWith('|Text|')) {
      try {
        part.texts.add(
          ScoreText(
            part.length,
            nwcString(field('Text')),
            int.tryParse(field('Pos')) ?? 0,
            field('Font'),
            rightAligned: field('Justify') == 'Right',
          ),
        );
      } catch (_) {}
    }
    if (!RegExp(r'^\|(Note|Chord|Rest|RestChord)\|').hasMatch(line)) {
      continue;
    }
    final dur = field('Dur');
    var length =
        {
          'Whole': 4.0,
          'Half': 2.0,
          '4th': 1.0,
          '8th': 0.5,
          '16th': 0.25,
          '32nd': 0.125,
          '64th': 0.0625,
        }[dur.split(',').first] ??
        1.0;
    if (dur.contains('DblDotted')) {
      length *= 1.75;
    } else if (dur.contains('Dotted')) {
      length *= 1.5;
    }
    if (dur.contains('Triplet')) length *= 2 / 3;
    final restChord = line.startsWith('|RestChord|');
    if (line.startsWith('|Rest|') && dur == 'Whole') length = meter;
    if (!line.startsWith('|Rest') || restChord) {
      final split = field('Dur2').isNotEmpty && field('Pos2').isNotEmpty;
      final components = [
        if (!restChord)
          (
            positions: field('Pos'),
            duration: dur,
            group: split ? 1 : 0,
            opts: field('Opts'),
          ),
        if (split)
          (
            positions: field('Pos2'),
            duration: field('Dur2'),
            group: 2,
            opts: [
              ...field('Opts')
                  .split(',')
                  .where(
                    (option) =>
                        !option.startsWith('Stem=') && option.isNotEmpty,
                  ),
              field('Opts').contains('Stem=Down') ? 'Stem=Up' : 'Stem=Down',
            ].join(','),
          ),
      ];
      for (final component in components) {
        for (final token in component.positions.split(',')) {
          final m = RegExp(r'([#bnxv]?)(-?\d+)').firstMatch(token);
          if (m == null) continue;
          final pos = int.parse(m.group(2)!);
          final absolute = clefMiddlePitch(clef) + pos;
          final degree = absolute % 7;
          var alt = accidental[absolute] ?? keyAccidental[degree] ?? 0;
          if (m.group(1)!.isNotEmpty) {
            alt = {'#': 1, 'b': -1, 'n': 0, 'x': 2, 'v': -2}[m.group(1)]!;
            accidental[absolute] = alt;
          }
          final note = Note(
            part.length,
            noteDuration(component.duration),
            12 +
                transpose +
                (absolute ~/ 7) * 12 +
                [0, 2, 4, 5, 7, 9, 11][degree] +
                alt +
                (part.octaveAt(part.length).contains('Down')
                    ? -12
                    : part.octaveAt(part.length).contains('Up')
                    ? 12
                    : 0),
            pos,
          );
          note.dur = component.duration;
          note.opts = component.opts;
          note.stemGroup = component.group;
          note.accidental = m.group(1)!;
          note.tie = token.contains('^');
          note.head = token.substring(m.end).replaceAll('^', '');
          part.notes.add(note);
        }
      }
      if (restChord) {
        part.rests.add(
          Note(part.length, length, 0, 0)
            ..dur = dur
            ..opts = field('Opts'),
        );
      }
      if (split) length = min(length, noteDuration(field('Dur2')));
    } else {
      part.rests.add(
        Note(part.length, length, 0, 0)
          ..dur = dur
          ..opts = field('Opts'),
      );
    }
    if (!dur.contains('Grace')) part.length += length;
  }
  final globalTempos = <double, double>{};
  final globalTempoUnits = <double, String>{};
  for (final p in parts) {
    globalTempos.addAll(p.tempoChanges);
    globalTempoUnits.addAll(p.tempoUnits);
  }
  for (final p in parts) {
    p.tempoChanges.addAll(globalTempos);
    p.tempoUnits.addAll(globalTempoUnits);
    for (final n in p.notes) {
      if (n.grace) continue;
      final targets = p.notes.where(
        (next) =>
            !next.grace && (next.beat - n.beat - n.duration).abs() < 0.00001,
      );
      if (n.tie) {
        final same = targets.where((next) => next.pos == n.pos);
        if (same.isNotEmpty) {
          n.tieTo = same.first;
          n.tieTo!.receivesTie = true;
          // An accidental continues through a tie even over a bar line.
          if (n.tieTo!.accidental.isEmpty) n.tieTo!.pitch = n.pitch;
        }
      }
      if (n.dur.contains('Slur') && targets.isNotEmpty) {
        n.slurTo = targets.first;
      }
    }
    final verses = p.verses.isEmpty ? {1: p.lyrics} : p.verses;
    for (final verse in verses.entries) {
      final syllables = lyricSyllables(verse.value);
      var index = 0;
      Note? previous;
      double lastBeat = -1;
      final events = [...p.notes, ...p.rests]..sort((a, b) {
        final time = a.beat.compareTo(b.beat);
        return time != 0 ? time : a.duration.compareTo(b.duration);
      });
      for (final n in events) {
        if (n.grace) continue;
        if (n.beat == lastBeat) continue;
        final automatic =
            p.notes.contains(n) &&
            !n.receivesTie &&
            previous?.slurTo != n &&
            !n.dur.contains('Grace');
        if (!n.opts.contains('Lyric=Never') &&
            (n.opts.contains('Lyric=Always') || automatic)) {
          if (index < syllables.length) {
            final syllable = syllables[index++];
            final value = syllable == '_' ? '' : syllable.replaceAll('_', ' ');
            n.lyricLines[verse.key] = value;
            if (verse.key == 1) n.lyric = value;
          }
        }
        lastBeat = n.beat;
        previous = n;
      }
    }
  }
  return parts;
}

Uint8List wav(
  List<Part> parts,
  double bpm,
  double startBeat, {
  Map<Part, double> gains = const {},
}) {
  const rate = 22050;
  final end = parts.map((p) => p.length).fold(startBeat, max);
  final samples = Float64List(
    (min(30.0, max(0.1, (end - startBeat) * 60 / bpm)) * rate).ceil(),
  );
  for (final p in parts) {
    for (final n in p.notes) {
      if (n.receivesTie || n.muted) continue;
      var sustained = n.duration;
      var tail = n;
      while (tail.tieTo != null) {
        tail = tail.tieTo!;
        sustained += tail.duration;
      }
      final start = ((n.beat - startBeat) * 60 / bpm * rate).round();
      final sounding =
          n.dur.contains('Staccato') && n.tieTo == null
              ? sustained * 0.5
              : sustained;
      final count = (sounding * 60 / bpm * rate).round();
      if (start + count <= 0 || start >= samples.length) continue;
      final frequency = 440 * pow(2, (n.pitch - 69) / 12);
      for (
        var i = max(0, -start);
        i < count && start + i < samples.length;
        i++
      ) {
        final envelope =
            min(1.0, i / (rate * 0.008)) *
            min(1.0, (count - i) / (rate * 0.025));
        samples[start + i] +=
            sin(2 * pi * frequency * i / rate) *
            envelope *
            0.65 *
            (gains[p] ?? 1.0) /
            sqrt(parts.length);
      }
    }
  }
  final bytes = Uint8List(44 + samples.length * 2);
  final d = ByteData.sublistView(bytes);
  void word(int at, int value) => d.setUint32(at, value, Endian.little);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  word(4, bytes.length - 8);
  bytes.setRange(8, 16, ascii.encode('WAVEfmt '));
  word(16, 16);
  d.setUint16(20, 1, Endian.little);
  d.setUint16(22, 1, Endian.little);
  word(24, rate);
  word(28, rate * 2);
  d.setUint16(32, 2, Endian.little);
  d.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, ascii.encode('data'));
  word(40, samples.length * 2);
  // Reduce only overloads: never normalize a deliberately quiet/muted part up.
  final peak = samples.fold(0.0, (value, sample) => max(value, sample.abs()));
  final limiter = peak > 0.95 ? 0.95 / peak : 1.0;
  for (var i = 0; i < samples.length; i++) {
    d.setInt16(
      44 + i * 2,
      ((samples[i] * limiter).clamp(-1, 1) * 32767).round(),
      Endian.little,
    );
  }
  return bytes;
}

class Lab extends StatefulWidget {
  const Lab({
    super.key,
    this.embedded = false,
    this.soundfontAsset = 'assets/soundfonts/piano.sf2',
    this.vipLicensedTo,
    this.proAccessOverride,
  });
  final bool embedded;
  final String soundfontAsset;
  final String? vipLicensedTo;

  /// Dependency injection for UI tests. Normal app entry points use real billing.
  /// The player owns and disposes this instance, including an injected instance.
  final ProAccess? proAccessOverride;
  @override
  State<Lab> createState() => _LabState();
}

class FavoriteScore {
  const FavoriteScore(this.name, this.data);
  final String name, data;
  Map<String, String> toJson() => {'name': name, 'data': data};
}

class _LabState extends State<Lab> {
  final livePlayer = LivePlayer();
  late final proAccess = widget.proAccessOverride ?? ProAccess();
  bool get proRequired =>
      requiresProAccess(embedded: widget.embedded, flavor: appFlavor);
  bool get proUnlocked => !proRequired || proAccess.unlocked;

  void showProOffer() {
    if (!proRequired || !mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProOfferSheet(access: proAccess),
    );
  }

  bool requirePro() {
    if (proUnlocked) return true;
    showProOffer();
    return false;
  }

  List<Part> sourceParts = [];
  List<Part> parts = [];
  List<Part> scoreParts = [];
  final pitchShifts = <double, int>{};
  int bar = 1;
  final enabled = <int>{};
  final visibleParts = <int>{};
  double scoreZoom = 1;
  final playbackBeat = ValueNotifier<double?>(null);
  final menuScroll = ScrollController();
  final playbackStartController = TextEditingController(text: '1');
  final loopStartController = TextEditingController(text: '1');
  final loopEndController = TextEditingController(text: '10');
  double? activeBeat;
  final volumes = <Part, double>{};
  double bpm = 157;
  double originalBpm = 157;
  bool busy = false;
  ByteData? pianoFont;
  int playbackRequest = 0;
  int scoreRequest = 0;
  bool _handlingBack = false;
  LocalizedText? _status;
  String get status => _status?.call(playerStrings(context)) ?? '';
  String fileName = 'NWC Player';
  Uint8List? currentFileBytes;
  List<FavoriteScore> favorites = [];
  bool favoritesLoaded = false;
  bool followScore = false;
  bool _hadPro = false;
  BuildContext? _landscapeContext;

  void rebuildTransposition() {
    final previousVolumes = [for (final part in parts) volumes[part] ?? 1.0];
    parts = [for (final part in sourceParts) transposePart(part, pitchShifts)];
    scoreParts = parts.map(displayScore).toList();
    volumes
      ..clear()
      ..addEntries([
        for (var i = 0; i < parts.length; i++)
          MapEntry(
            parts[i],
            i < previousVolumes.length ? previousVolumes[i] : 1.0,
          ),
      ]);
  }

  int measureAt(double beat) {
    if (sourceParts.isEmpty) return 1;
    var index = 0;
    final starts = sourceParts.first.barStarts;
    while (index + 1 < starts.length && starts[index + 1] <= beat + .000001) {
      index++;
    }
    return index + 1;
  }

  int get lastMeasure =>
      scoreParts.isEmpty ? 1 : max(1, (scoreParts.first.length / 4).ceil());

  int loopValue(TextEditingController controller, int fallback) =>
      (int.tryParse(controller.text) ?? fallback).clamp(1, lastMeasure);

  void commitPlaybackStart() {
    if (livePlayer.playing) return;
    final value = loopValue(playbackStartController, bar);
    setState(() {
      bar = value;
      playbackStartController.text = '$value';
    });
  }

  void adjustPlaybackStart(int delta) {
    if (livePlayer.playing) return;
    final value = (loopValue(playbackStartController, bar) + delta).clamp(
      1,
      lastMeasure,
    );
    setState(() {
      bar = value;
      playbackStartController.text = '$value';
    });
  }

  String get currentTonic {
    if (sourceParts.isEmpty) return 'C';
    final beats = pitchShifts.keys.toList()..sort();
    final firstBeat = beats.isEmpty ? 0.0 : beats.first;
    return signatureTonic(
      transposeSignature(
        sourceParts.first.keyAt(firstBeat),
        pitchShifts[firstBeat] ?? 0,
      ),
    );
  }

  void adjustLoop(TextEditingController controller, int delta) {
    if (livePlayer.playing) return;
    final value = (loopValue(controller, 1) + delta).clamp(1, lastMeasure);
    setState(() => controller.text = '$value');
  }

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('nwc_favorites_v1');
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final loaded = [
        for (final item in decoded)
          if (item is Map && item['name'] is String && item['data'] is String)
            FavoriteScore(item['name'] as String, item['data'] as String),
      ];
      if (mounted) setState(() => favorites = loaded);
    } catch (_) {
      // Ignore corrupt local favorites without affecting score loading.
    }
  }

  Future<void> saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'nwc_favorites_v1',
      jsonEncode(favorites.map((item) => item.toJson()).toList()),
    );
  }

  String? get currentFavoriteData {
    final bytes = currentFileBytes;
    if (bytes == null) return null;
    final encoded = base64Encode(bytes);
    return favorites.any(
          (item) => item.name == fileName && item.data == encoded,
        )
        ? encoded
        : null;
  }

  Future<void> toggleFavorite() async {
    if (!requirePro()) return;
    final bytes = currentFileBytes;
    if (bytes == null) return;
    final encoded = base64Encode(bytes);
    final index = favorites.indexWhere(
      (item) => item.name == fileName && item.data == encoded,
    );
    if (index >= 0) {
      setState(() => favorites.removeAt(index));
    } else {
      if (bytes.length > 2 * 1024 * 1024) {
        setState(() => _status = (s) => s.favoriteTooLarge);
        return;
      }
      setState(() => favorites.add(FavoriteScore(fileName, encoded)));
    }
    await saveFavorites();
  }

  @override
  void initState() {
    super.initState();
    proAccess.addListener(_onProAccessChanged);
    if (proRequired) proAccess.initialize();
    if (!proRequired) {
      favoritesLoaded = true;
      loadFavorites();
    }
    livePlayer.onProgress = (seconds, ended) {
      if (!mounted || parts.isEmpty) return;
      final current =
          (parts.isEmpty
              ? livePlayer.beatAt(seconds)
              : parts.first.displayBeat(livePlayer.beatAt(seconds))) /
          4;
      activeBeat = ended ? null : current * 4;
      playbackBeat.value = activeBeat;
      if (ended) {
        setState(() {
          _status = (s) => s.playbackFinished;
        });
      }
    };
    livePlayer.onError = (error) {
      if (mounted) {
        setState(
          () => _status = (s) => s.realtimeError(playerErrorText(error, s)),
        );
      }
    };
  }

  void _onProAccessChanged() {
    final lostAccess = _hadPro && !proAccess.unlocked;
    _hadPro = proAccess.unlocked;
    if (lostAccess && mounted) {
      playbackRequest++;
      unawaited(livePlayer.stop());
      activeBeat = null;
      playbackBeat.value = null;
      busy = false;
      for (final key in pitchShifts.keys.toList()) {
        pitchShifts[key] = 0;
      }
      rebuildTransposition();
      volumes.clear();
      enabled
        ..clear()
        ..addAll(List.generate(parts.length, (i) => i));
      visibleParts
        ..clear()
        ..addAll(enabled);
      bar = 1;
      playbackStartController.text = '1';
      bpm = originalBpm;
      scoreZoom = 1;
      followScore = false;
      final landscapeContext = _landscapeContext;
      if (landscapeContext != null && landscapeContext.mounted) {
        Navigator.of(landscapeContext).pop();
      }
    }
    if (mounted) setState(() {});
    unawaited(LauncherIconController.setPro(proAccess.unlocked));
    if (proAccess.unlocked && !favoritesLoaded) {
      favoritesLoaded = true;
      loadFavorites();
    }
  }

  bool get supportsScoreFolders =>
      !widget.embedded &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  Future<void> load({bool fromFolder = false}) async {
    if (busy) return;
    final request = ++scoreRequest;
    setState(() => busy = true);
    try {
      playbackRequest++;
      await livePlayer.stop();
      if (!mounted || request != scoreRequest) return;
      if (mounted) {
        setState(() {
          activeBeat = null;
          playbackBeat.value = null;
        });
      }
      final file =
          fromFolder
              ? await showScoreFolderPicker(context)
              : await pickScoreFile();
      if (file == null || !mounted || request != scoreRequest) return;
      final bytes = await readScoreFile(file);
      if (!mounted || request != scoreRequest) return;
      await openScore(file.name, bytes, request: request);
    } catch (e) {
      if (mounted && request == scoreRequest) await showScoreReadError(e);
    } finally {
      if (mounted && request == scoreRequest) setState(() => busy = false);
    }
  }

  Future<void> loadWebExample() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await livePlayer.stop();
      final text = StringBuffer('!NoteWorthyComposer(2.75)\n|SongInfo|Title:"AST 연습 예제"\n|AddStaff|Name:"연습 파트"\n|Clef|Type:Treble\n|TimeSig|Signature:4/4\n|Tempo|Tempo:100\n');
      for (var bar = 0; bar < 8; bar++) {
        for (final pos in [-6, -4, -2, -1]) { text.writeln('|Note|Dur:4th|Pos:$pos'); }
        text.writeln('|Bar');
      }
      text.writeln('!NoteWorthyComposer-End');
      await openScore('AST 연습 예제.nwctxt', Uint8List.fromList(utf8.encode(text.toString())));
    } catch (e) { if (mounted) await showScoreReadError(e); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> showScoreReadError(Object error, {bool favorite = false}) async {
    if (!mounted) return;
    String message(NwcLocalizations s) =>
        favorite
            ? s.favoriteFailed(playerErrorText(error, s))
            : s.readFailed(playerErrorText(error, s));
    setState(() => _status = message);
    // An error in a new selection must be visible even with a score already open.
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final strings = playerStrings(dialogContext);
        return AlertDialog(
          content: Text(message(strings)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.close),
            ),
          ],
        );
      },
    );
  }

  Future<void> openFavorite(FavoriteScore favorite) async {
    if (!requirePro()) return;
    if (busy) return;
    final request = ++scoreRequest;
    setState(() => busy = true);
    try {
      playbackRequest++;
      await livePlayer.stop();
      if (!mounted || request != scoreRequest) return;
      playbackBeat.value = null;
      validateScoreName(favorite.name);
      if (favorite.data.length > ((maxScoreFileBytes + 2) ~/ 3) * 4) {
        throw const ScoreReadException(ScoreReadError.tooLarge);
      }
      await openScore(
        favorite.name,
        base64Decode(favorite.data),
        request: request,
      );
    } catch (e) {
      if (mounted && request == scoreRequest) {
        await showScoreReadError(e, favorite: true);
      }
    } finally {
      if (mounted && request == scoreRequest) setState(() => busy = false);
    }
  }

  Future<void> openScore(String name, Uint8List bytes, {int? request}) async {
    final currentRequest = request ?? ++scoreRequest;
    if (!mounted || currentRequest != scoreRequest) return;
    validateScoreName(name);
    final result = parse(bytes);
    if (result.isEmpty || result.length > 16) {
      throw const ScoreReadException(ScoreReadError.unsupportedParts);
    }
    // Do not load the large SoundFont for a rejected or damaged file.
    pianoFont ??= await rootBundle.load(widget.soundfontAsset);
    if (mounted && currentRequest == scoreRequest) {
      setState(() {
        sourceParts = result;
        pitchShifts
          ..clear()
          ..addEntries(
            (<double>{0, for (final p in result) ...p.keyChanges.keys}.toList()
                  ..sort())
                .map((beat) => MapEntry(beat, 0)),
          );
        rebuildTransposition();
        fileName = name;
        currentFileBytes = Uint8List.fromList(bytes);
        bar = 1;
        playbackStartController.text = '1';
        originalBpm = (result.first.tempoChanges[0] ?? 157).clamp(30, 300);
        bpm = originalBpm;
        enabled.clear();
        visibleParts
          ..clear()
          ..addAll(List.generate(parts.length, (i) => i));
        scoreZoom = 1;
        volumes.clear();
        enabled.addAll(List.generate(parts.length, (i) => i));
        _status = null;
        loopStartController.text = '1';
        loopEndController.text = '${min(10, lastMeasure)}';
      });
    }
  }

  Future<void> play(bool all) async {
    if (!all && !requirePro()) return;
    if (busy || livePlayer.playing) return;
    bar = loopValue(playbackStartController, bar);
    playbackStartController.text = '$bar';
    final request = ++playbackRequest;
    setState(() {
      busy = true;
      activeBeat = null;
      playbackBeat.value = null;
      _status = (s) => s.preparingPlayback;
    });
    try {
      await livePlayer.stop();
      if (!mounted || request != playbackRequest) return;
      final chosen = all ? parts : [for (final i in enabled) parts[i]];
      if (chosen.isEmpty) return;
      {
        if (all) {
          setState(() {
            enabled.addAll(List.generate(parts.length, (i) => i));
          });
        }
        await livePlayer.play(
          pianoFont!,
          parts,
          bpm,
          parts.first.beatAtBar(bar - 1),
          Map.of(volumes),
          Set.of(enabled),
          title: fileName,
        );
        if (mounted && request == playbackRequest) {
          setState(() => _status = (s) => s.playing);
        }
        return;
      }
    } catch (e) {
      if (mounted && request == playbackRequest) {
        setState(
          () => _status = (s) => s.playbackFailed(playerErrorText(e, s)),
        );
      }
    } finally {
      if (mounted && request == playbackRequest) setState(() => busy = false);
    }
  }

  Future<void> playLoop() async {
    if (!requirePro()) return;
    if (busy || livePlayer.playing || parts.isEmpty) return;
    var from = loopValue(loopStartController, 1);
    var to = loopValue(loopEndController, min(10, lastMeasure));
    if (from > to) (from, to) = (to, from);
    final loopTitle = playerStrings(context).loopTitle(fileName, from, to);
    loopStartController.text = '$from';
    loopEndController.text = '$to';
    final request = ++playbackRequest;
    setState(() {
      busy = true;
      activeBeat = null;
      playbackBeat.value = null;
      _status = (s) => s.preparingLoop;
    });
    try {
      await livePlayer.stop();
      if (!mounted || request != playbackRequest) return;
      if (enabled.isEmpty) return;
      final startBeat = parts.first.beatAtBar(from - 1);
      final endBeat = parts.first.beatAtBar(to);
      await livePlayer.play(
        pianoFont!,
        parts,
        bpm,
        startBeat,
        Map.of(volumes),
        Set.of(enabled),
        title: loopTitle,
        endBeat: endBeat,
        loop: true,
      );
      if (mounted && request == playbackRequest) {
        setState(() => _status = (s) => s.loopStatus(from, to));
      }
    } catch (e) {
      if (mounted && request == playbackRequest) {
        setState(() => _status = (s) => s.loopFailed(playerErrorText(e, s)));
      }
    } finally {
      if (mounted && request == playbackRequest) setState(() => busy = false);
    }
  }

  Future<void> handleStandaloneBack() async {
    if (!mounted || widget.embedded || _handlingBack) return;
    _handlingBack = true;
    try {
      if (parts.isNotEmpty || busy) {
        // Invalidate file reads/audio preparation before clearing the score so
        // a late asynchronous result cannot reopen it or restart playback.
        scoreRequest++;
        playbackRequest++;
        final stopping = livePlayer.stop();
        setState(() {
          sourceParts = [];
          parts = [];
          scoreParts = [];
          pitchShifts.clear();
          volumes.clear();
          enabled.clear();
          visibleParts.clear();
          currentFileBytes = null;
          fileName = 'NWC Player';
          activeBeat = null;
          playbackBeat.value = null;
          bar = 1;
          playbackStartController.text = '1';
          loopStartController.text = '1';
          loopEndController.text = '10';
          bpm = originalBpm = 157;
          scoreZoom = 1;
          followScore = false;
          busy = false;
          _status = null;
        });
        // A device audio teardown failure must not trap the user on the score.
        try {
          await stopping;
        } catch (_) {}
        return;
      }
      final exit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final strings = playerStrings(dialogContext);
          return AlertDialog(
            key: const ValueKey('confirm-player-exit'),
            title: Text(strings.exitAppTitle),
            content: Text(strings.exitAppMessage),
            actions: [
              TextButton(
                key: const ValueKey('cancel-player-exit'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(strings.cancelExit),
              ),
              FilledButton(
                key: const ValueKey('accept-player-exit'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(strings.exitPlayer),
              ),
            ],
          );
        },
      );
      if (exit == true && mounted) {
        scoreRequest++;
        playbackRequest++;
        try {
          await livePlayer.stop();
        } catch (_) {}
        if (mounted) await SystemNavigator.pop();
      }
    } finally {
      _handlingBack = false;
    }
  }

  @override
  void dispose() {
    proAccess.removeListener(_onProAccessChanged);
    proAccess.dispose();
    playbackRequest++;
    scoreRequest++;
    livePlayer.onProgress = null;
    livePlayer.onError = null;
    livePlayer.stop();
    playbackBeat.dispose();
    menuScroll.dispose();
    playbackStartController.dispose();
    loopStartController.dispose();
    loopEndController.dispose();
    super.dispose();
  }

  List<Part> get shownParts => [
    for (var i = 0; i < parts.length; i++)
      if (visibleParts.contains(i)) scoreParts[i],
  ];

  Future<void> landscape() async {
    if (!requirePro()) return;
    final selected = shownParts;
    if (selected.isEmpty) return;
    final baseScale = (MediaQuery.sizeOf(context).width - 32) / 2210 * 1.65;
    var zoom = 1.0;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    try {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        useSafeArea: false,
        builder: (context) {
          _landscapeContext = context;
          return Dialog.fullscreen(
            child: SafeArea(
              child: StatefulBuilder(
                builder:
                    (context, update) => Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                                label: Text(
                                  playerStrings(context).closeLandscape,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: followScore,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (value) {
                                      final next = value ?? false;
                                      update(() => followScore = next);
                                      if (mounted) {
                                        setState(() => followScore = next);
                                      }
                                    },
                                  ),
                                  Text(
                                    playerStrings(context).followScore,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              PlaybackBarLabel(beat: playbackBeat),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: playerStrings(context).zoomOut,
                                    onPressed:
                                        zoom > 1
                                            ? () => update(() => zoom -= .25)
                                            : null,
                                    icon: const Icon(Icons.remove),
                                  ),
                                  Text('${(zoom * 100).round()}%'),
                                  IconButton(
                                    tooltip: playerStrings(context).zoomIn,
                                    onPressed:
                                        zoom < 5
                                            ? () => update(() => zoom += .25)
                                            : null,
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ScoreViewport(
                            parts: selected,
                            tempo: bpm,
                            beatListenable: playbackBeat,
                            followPlayback: followScore,
                            scale: baseScale * zoom,
                            continuous: true,
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          );
        },
      );
    } finally {
      _landscapeContext = null;
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.embedded,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !widget.embedded) {
        unawaited(handleStandaloneBack());
      }
      if (didPop && widget.embedded) {
        playbackRequest++;
        livePlayer.stop();
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    },
    child: Scaffold(
      key: const ValueKey('nwc-player'),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: 3),
          child: Text(
            '© 2026 LUCENTY Labs. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Color(0xff807a8c)),
          ),
        ),
      ),
      appBar: AppBar(
        title: Row(
          children: [
            if (parts.isNotEmpty)
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: Color(0xffeee9fa),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  key: const ValueKey('favorite-score'),
                  padding: EdgeInsets.zero,
                  tooltip:
                      currentFavoriteData == null
                          ? playerStrings(context).addFavorite
                          : playerStrings(context).removeFavorite,
                  onPressed: toggleFavorite,
                  icon: Icon(
                    currentFavoriteData == null
                        ? Icons.star_border
                        : Icons.star,
                    color: const Color(0xff7257a8),
                    size: 22,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.vipLicensedTo == null
                        ? 'NWC Player'
                        : 'NWC Player VIP · Licensed to ${widget.vipLicensedTo}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xff655a83),
                    ),
                  ),
                  if (parts.isNotEmpty)
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!widget.embedded)
            IconButton(
              onPressed: () => showPlayerInformation(context),
              icon: const Icon(Icons.info_outline),
              tooltip: playerStrings(context).appInformation,
            ),
          if (parts.isNotEmpty)
            if (supportsScoreFolders)
              PopupMenuButton<bool>(
                enabled: !busy,
                tooltip: playerStrings(context).openFile,
                icon: const Icon(Icons.folder_open),
                onSelected: (folder) => load(fromFolder: folder),
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: false,
                        child: Text(playerStrings(context).openFile),
                      ),
                      PopupMenuItem(
                        value: true,
                        child: Text(playerStrings(context).scoreFolder),
                      ),
                    ],
              )
            else
              IconButton(
                onPressed: busy ? null : load,
                icon: const Icon(Icons.folder_open),
                tooltip: playerStrings(context).openFile,
              ),
          if (proRequired && MediaQuery.sizeOf(context).width < 420)
            IconButton(
              tooltip: proUnlocked ? 'Pro' : playerStrings(context).unlockPro,
              onPressed: showProOffer,
              icon: Icon(proUnlocked ? Icons.verified : Icons.lock_outline),
            ),
          if (proRequired && MediaQuery.sizeOf(context).width >= 420)
            TextButton.icon(
              onPressed: showProOffer,
              icon: Icon(proUnlocked ? Icons.verified : Icons.lock_outline),
              label: Text(
                proUnlocked ? 'Pro' : playerStrings(context).unlockPro,
              ),
            ),
          if (widget.embedded && MediaQuery.sizeOf(context).width < 420)
            IconButton(
              key: const ValueKey('exit-nwc-player'),
              tooltip: playerStrings(context).exitPlayer,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          if (widget.embedded && MediaQuery.sizeOf(context).width >= 420)
            TextButton.icon(
              key: const ValueKey('exit-nwc-player'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              label: Text(playerStrings(context).exitPlayer),
            ),
        ],
      ),
      body:
          parts.isEmpty
              ? ScoreStartScreen(
                busy: busy,
                status: status,
                favorites: proUnlocked ? favorites : const [],
                onOpen: load,
                onExample: kIsWeb ? loadWebExample : null,
                onFolder:
                    supportsScoreFolders ? () => load(fromFolder: true) : null,
                onFavorite: openFavorite,
              )
              : Column(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * .40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xfff2f0fa),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Scrollbar(
                        controller: menuScroll,
                        thumbVisibility: true,
                        child: ListView(
                          controller: menuScroll,
                          padding: const EdgeInsets.all(16),
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.tune,
                                  size: 20,
                                  color: Color(0xff655a83),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  playerStrings(context).performanceMenu,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (status.isNotEmpty)
                              ValueListenableBuilder<double?>(
                                valueListenable: playbackBeat,
                                builder:
                                    (context, beat, _) => Text(
                                      beat == null
                                          ? status
                                          : playerStrings(
                                            context,
                                          ).playbackProgress(
                                            status,
                                            (beat / 4).floor() + 1,
                                            TempoMap(
                                              scoreParts,
                                              bpm,
                                            ).bpmAt(beat).round(),
                                          ),
                                    ),
                              ),
                            if (parts.isEmpty)
                              Center(
                                child: FilledButton(
                                  onPressed: busy ? null : load,
                                  child: Text(playerStrings(context).openFile),
                                ),
                              ),
                            MenuSection(
                              title: playerStrings(context).partVolumes,
                              locked: !proUnlocked,
                              onUnlock: showProOffer,
                              child: Column(
                                children: [
                                  for (var i = 0; i < parts.length; i++)
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: enabled.contains(i),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                enabled.add(i);
                                              } else {
                                                enabled.remove(i);
                                              }
                                            });
                                            livePlayer.volume(
                                              parts[i],
                                              enabled.contains(i)
                                                  ? (volumes[parts[i]] ?? 1)
                                                  : 0,
                                            );
                                          },
                                        ),
                                        SizedBox(
                                          width: 72,
                                          child: Text(
                                            parts[i].name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: volumes[parts[i]] ?? 1.0,
                                            min: 0,
                                            max: 1,
                                            label:
                                                '${((volumes[parts[i]] ?? 1.0) * 100).round()}%',
                                            onChanged: (value) {
                                              setState(
                                                () => volumes[parts[i]] = value,
                                              );
                                              livePlayer.volume(
                                                parts[i],
                                                enabled.contains(i) ? value : 0,
                                              );
                                            },
                                          ),
                                        ),
                                        SizedBox(
                                          width: 45,
                                          child: Text(
                                            '${((volumes[parts[i]] ?? 1.0) * 100).round()}%',
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            MenuSection(
                              title: playerStrings(context).pitchAdjustment,
                              locked: !proUnlocked,
                              onUnlock: showProOffer,
                              trailing: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    playerStrings(
                                      context,
                                    ).tonic(pitchPipeTonic(currentTonic)),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed:
                                        livePlayer.playing ||
                                                pitchShifts.values.every(
                                                  (v) => v == 0,
                                                )
                                            ? null
                                            : () => setState(() {
                                              for (final beat
                                                  in pitchShifts.keys
                                                      .toList()) {
                                                pitchShifts[beat] = 0;
                                              }
                                              rebuildTransposition();
                                            }),
                                    child: Text(
                                      playerStrings(context).originalPitch,
                                    ),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    playerStrings(context).pitchHelp,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xff655a83),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  for (var i = 0; i < pitchShifts.length; i++)
                                    Builder(
                                      builder: (context) {
                                        final beats = pitchShifts.keys.toList();
                                        final beat = beats[i];
                                        final value = pitchShifts[beat] ?? 0;
                                        final from = measureAt(beat);
                                        final until =
                                            i + 1 < beats.length
                                                ? measureAt(beats[i + 1]) - 1
                                                : null;
                                        return Row(
                                          key: ValueKey('pitch-section-$beat'),
                                          children: [
                                            Expanded(
                                              child: Text(
                                                until == null
                                                    ? playerStrings(
                                                      context,
                                                    ).fromBar(from)
                                                    : playerStrings(
                                                      context,
                                                    ).barRange(from, until),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip:
                                                  playerStrings(
                                                    context,
                                                  ).lowerPitch,
                                              onPressed:
                                                  livePlayer.playing ||
                                                          value <= -4
                                                      ? null
                                                      : () => setState(() {
                                                        pitchShifts[beat] =
                                                            value - 1;
                                                        rebuildTransposition();
                                                      }),
                                              icon: const Icon(Icons.remove),
                                            ),
                                            SizedBox(
                                              width: 38,
                                              child: Text(
                                                value > 0
                                                    ? '+$value'
                                                    : '$value',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip:
                                                  playerStrings(
                                                    context,
                                                  ).raisePitch,
                                              onPressed:
                                                  livePlayer.playing ||
                                                          value >= 4
                                                      ? null
                                                      : () => setState(() {
                                                        pitchShifts[beat] =
                                                            value + 1;
                                                        rebuildTransposition();
                                                      }),
                                              icon: const Icon(Icons.add),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            MenuSection(
                              title: playerStrings(context).playback,
                              child: Column(
                                children: [
                                  if (!proUnlocked)
                                    ProLockedControl(onUnlock: showProOffer),
                                  if (proUnlocked) ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            playerStrings(context).startBar,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip:
                                              playerStrings(
                                                context,
                                              ).previousBar,
                                          onPressed:
                                              !livePlayer.playing && bar > 1
                                                  ? () =>
                                                      adjustPlaybackStart(-1)
                                                  : null,
                                          icon: const Icon(Icons.remove),
                                        ),
                                        SizedBox(
                                          width: 86,
                                          child: TextField(
                                            key: const ValueKey(
                                              'playback-start-field',
                                            ),
                                            controller: playbackStartController,
                                            enabled: !livePlayer.playing,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            textAlign: TextAlign.center,
                                            decoration: InputDecoration(
                                              suffixText:
                                                  playerStrings(
                                                    context,
                                                  ).barUnit,
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                            ),
                                            onSubmitted:
                                                (_) => commitPlaybackStart(),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip:
                                              playerStrings(context).nextBar,
                                          onPressed:
                                              livePlayer.playing ||
                                                      bar >= lastMeasure
                                                  ? null
                                                  : () =>
                                                      adjustPlaybackStart(1),
                                          icon: const Icon(Icons.add),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 68,
                                          child: Text('${bpm.round()} BPM'),
                                        ),
                                        IconButton(
                                          tooltip:
                                              playerStrings(context).lowerBpm,
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 34,
                                            minHeight: 36,
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed:
                                              livePlayer.playing || bpm <= 30
                                                  ? null
                                                  : () => setState(
                                                    () =>
                                                        bpm =
                                                            (bpm - 1)
                                                                .clamp(30, 300)
                                                                .toDouble(),
                                                  ),
                                          icon: const Icon(Icons.remove),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: bpm,
                                            min: 30,
                                            max: 300,
                                            onChanged:
                                                livePlayer.playing
                                                    ? null
                                                    : (v) =>
                                                        setState(() => bpm = v),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip:
                                              playerStrings(context).raiseBpm,
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 34,
                                            minHeight: 36,
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed:
                                              livePlayer.playing || bpm >= 300
                                                  ? null
                                                  : () => setState(
                                                    () =>
                                                        bpm =
                                                            (bpm + 1)
                                                                .clamp(30, 300)
                                                                .toDouble(),
                                                  ),
                                          icon: const Icon(Icons.add),
                                        ),
                                        SizedBox(
                                          width: 74,
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: Size.zero,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 7,
                                                  ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            onPressed:
                                                livePlayer.playing ||
                                                        (bpm - originalBpm)
                                                                .abs() <
                                                            .001
                                                    ? null
                                                    : () => setState(
                                                      () => bpm = originalBpm,
                                                    ),
                                            child: Text(
                                              playerStrings(
                                                context,
                                              ).originalSpeed,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  PlaybackControls(
                                    hasParts: parts.isNotEmpty,
                                    busy: busy,
                                    playing: livePlayer.playing,
                                    paused: livePlayer.paused,
                                    onSelected: () => play(false),
                                    onAll: () => play(true),
                                    onPause: () {
                                      livePlayer.pause();
                                      setState(
                                        () =>
                                            _status =
                                                livePlayer.paused
                                                    ? (s) => s.pause
                                                    : (s) => s.resumedPlayback,
                                      );
                                    },
                                    onStop: () async {
                                      playbackRequest++;
                                      await livePlayer.stop();
                                      if (mounted) {
                                        setState(() {
                                          _status = (s) => s.stoppedPlayback;
                                          activeBeat = null;
                                          playbackBeat.value = null;
                                          busy = false;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (proUnlocked)
                              RangeRepeatControls(
                                enabled: !busy && !livePlayer.playing,
                                startController: loopStartController,
                                endController: loopEndController,
                                onStartDown:
                                    () => adjustLoop(loopStartController, -1),
                                onStartUp:
                                    () => adjustLoop(loopStartController, 1),
                                onEndDown:
                                    () => adjustLoop(loopEndController, -1),
                                onEndUp: () => adjustLoop(loopEndController, 1),
                                onPlay: playLoop,
                              )
                            else
                              MenuSection(
                                title: playerStrings(context).repeatSection,
                                child: ProLockedControl(onUnlock: showProOffer),
                              ),
                            if (parts.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              MenuSection(
                                title: playerStrings(context).score,
                                locked: !proUnlocked,
                                onUnlock: showProOffer,
                                child: Column(
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(playerStrings(context).scoreSize),
                                        IconButton(
                                          tooltip:
                                              playerStrings(context).zoomOut,
                                          onPressed:
                                              scoreZoom > 1
                                                  ? () => setState(
                                                    () =>
                                                        scoreZoom = (scoreZoom -
                                                                .25)
                                                            .clamp(1, 5),
                                                  )
                                                  : null,
                                          icon: const Icon(Icons.remove),
                                        ),
                                        Text('${(scoreZoom * 100).round()}%'),
                                        IconButton(
                                          tooltip:
                                              playerStrings(context).zoomIn,
                                          onPressed:
                                              () => setState(
                                                () =>
                                                    scoreZoom = (scoreZoom +
                                                            .25)
                                                        .clamp(1, 5),
                                              ),
                                          icon: const Icon(Icons.add),
                                        ),
                                        const SizedBox(width: 14),
                                        OutlinedButton(
                                          onPressed:
                                              shownParts.isEmpty
                                                  ? null
                                                  : landscape,
                                          child: Text(
                                            playerStrings(context).landscape,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Wrap(
                                      children: [
                                        for (var i = 0; i < parts.length; i++)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Checkbox(
                                                value: visibleParts.contains(i),
                                                onChanged:
                                                    (v) => setState(() {
                                                      if (v == true) {
                                                        visibleParts.add(i);
                                                      } else {
                                                        visibleParts.remove(i);
                                                      }
                                                    }),
                                              ),
                                              Text(parts[i].name),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffe5e0f3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffd6cfea)),
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tune, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(playerStrings(context).scrollMenu),
                        ),
                        Icon(Icons.unfold_more, size: 20),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xffe9edf3),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xffccd3e0)),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.music_note, size: 18),
                                    const SizedBox(width: 6),
                                    Text(playerStrings(context).score),
                                  ],
                                ),
                                PlaybackBarLabel(beat: playbackBeat),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: followScore,
                                      visualDensity: VisualDensity.compact,
                                      onChanged:
                                          proUnlocked
                                              ? (value) => setState(
                                                () =>
                                                    followScore =
                                                        value ?? false,
                                              )
                                              : (_) => showProOffer(),
                                    ),
                                    Text(
                                      playerStrings(context).followScore,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    const Icon(Icons.swipe, size: 18),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder:
                                  (context, bounds) =>
                                      shownParts.isEmpty
                                          ? Center(
                                            child: Text(
                                              playerStrings(
                                                context,
                                              ).selectParts,
                                            ),
                                          )
                                          : ScoreViewport(
                                            key: ValueKey(parts),
                                            parts: shownParts,
                                            tempo: bpm,
                                            beatListenable: playbackBeat,
                                            followPlayback: followScore,
                                            scale:
                                                (bounds.maxWidth - 32) /
                                                2210 *
                                                1.65 *
                                                scoreZoom,
                                          ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    ),
  );
}

class ScoreStartScreen extends StatelessWidget {
  const ScoreStartScreen({
    super.key,
    required this.busy,
    required this.status,
    this.favorites = const [],
    required this.onOpen,
    this.onExample,
    this.onFolder,
    this.onFavorite,
  });
  final bool busy;
  final String status;
  final List<FavoriteScore> favorites;
  final VoidCallback onOpen;
  final VoidCallback? onExample;
  final VoidCallback? onFolder;
  final ValueChanged<FavoriteScore>? onFavorite;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        Container(
          height: 64,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xfff2f0fa),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Icon(Icons.tune, color: Color(0xff655a83)),
              SizedBox(width: 10),
              Text(
                playerStrings(context).performanceMenu,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xffe9edf3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xffccd3e0)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.music_note, size: 18),
                      SizedBox(width: 6),
                      Text(playerStrings(context).score),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _ScoreStartContent(
                      scrollable: onFolder != null || onExample != null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.library_music_outlined,
                              size: 48,
                              color: Color(0xff655a83),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: busy ? null : onOpen,
                            icon:
                                busy
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.folder_open),
                            label: Text(
                              busy
                                  ? playerStrings(context).readingFile
                                  : playerStrings(context).openNwcFile,
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 18,
                              ),
                            ),
                          ),
                          if (onExample != null) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: busy ? null : onExample,
                              icon: const Icon(Icons.music_note_outlined),
                              label: const Text('예제 악보 열기'),
                            ),
                          ],
                          if (onFolder != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              key: const ValueKey('open-score-folder'),
                              onPressed: busy ? null : onFolder,
                              icon: const Icon(Icons.folder_special_outlined),
                              label: Text(playerStrings(context).scoreFolder),
                            ),
                          ],
                          if (favorites.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 19,
                                  color: Color(0xff7257a8),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  playerStrings(context).favorites,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 420,
                                maxHeight: 180,
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: favorites.length,
                                itemBuilder: (context, index) {
                                  final favorite = favorites[index];
                                  return Card(
                                    child: ListTile(
                                      dense: true,
                                      leading: const CircleAvatar(
                                        radius: 16,
                                        child: Icon(Icons.star, size: 18),
                                      ),
                                      title: Text(
                                        favorite.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: const Icon(Icons.play_arrow),
                                      onTap:
                                          busy || onFavorite == null
                                              ? null
                                              : () => onFavorite!(favorite),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (status.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(status, textAlign: TextAlign.center),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScoreStartContent extends StatelessWidget {
  const _ScoreStartContent({required this.scrollable, required this.child});
  final bool scrollable;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      scrollable ? SingleChildScrollView(child: child) : child;
}

class MenuSection extends StatelessWidget {
  const MenuSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.locked = false,
    this.onUnlock,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool locked;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xffd6cfea)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (locked) const Icon(Icons.lock_outline, size: 18),
              if (!locked && trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          locked ? ProLockedControl(onUnlock: onUnlock) : child,
        ],
      ),
    ),
  );
}

class ProLockedControl extends StatelessWidget {
  const ProLockedControl({super.key, this.onUnlock});
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onUnlock,
    icon: const Icon(Icons.workspace_premium_outlined),
    label: Text(playerStrings(context).lockedControl),
  );
}

class RangeRepeatControls extends StatelessWidget {
  const RangeRepeatControls({
    super.key,
    required this.enabled,
    required this.startController,
    required this.endController,
    required this.onStartDown,
    required this.onStartUp,
    required this.onEndDown,
    required this.onEndUp,
    required this.onPlay,
  });
  final bool enabled;
  final TextEditingController startController, endController;
  final VoidCallback onStartDown, onStartUp, onEndDown, onEndUp, onPlay;

  Widget field(
    BuildContext context,
    String label,
    TextEditingController controller,
    VoidCallback down,
    VoidCallback up,
  ) => Expanded(
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: label,
              suffixText: playerStrings(context).barUnit,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 25,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: enabled ? up : null,
                icon: const Icon(Icons.keyboard_arrow_up, size: 21),
              ),
            ),
            SizedBox(
              width: 34,
              height: 25,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: enabled ? down : null,
                icon: const Icon(Icons.keyboard_arrow_down, size: 21),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xffd6cfea)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            playerStrings(context).repeatSection,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              field(
                context,
                playerStrings(context).start,
                startController,
                onStartDown,
                onStartUp,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('~'),
              ),
              field(
                context,
                playerStrings(context).end,
                endController,
                onEndDown,
                onEndUp,
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('range-repeat-play'),
            onPressed: enabled ? onPlay : null,
            icon: const Icon(Icons.repeat),
            label: Text(playerStrings(context).playLoop),
          ),
        ],
      ),
    ),
  );
}

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({
    super.key,
    required this.hasParts,
    required this.busy,
    required this.playing,
    required this.paused,
    required this.onSelected,
    required this.onAll,
    required this.onPause,
    required this.onStop,
  });
  final bool hasParts, busy, playing, paused;
  final VoidCallback onSelected, onAll, onPause, onStop;
  @override
  Widget build(BuildContext context) {
    final canPlay = hasParts && !busy && !playing;
    final canStop = playing && !busy;
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    Widget button(String label, VoidCallback? callback) => Expanded(
      child: OutlinedButton(
        style: style,
        onPressed: callback,
        child: Text(label),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            button(
              playerStrings(context).playSelected,
              canPlay ? onSelected : null,
            ),
            const SizedBox(width: 8),
            button(playerStrings(context).playAll, canPlay ? onAll : null),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            button(
              paused
                  ? playerStrings(context).resume
                  : playerStrings(context).pause,
              canStop ? onPause : null,
            ),
            const SizedBox(width: 8),
            button(playerStrings(context).stop, canStop ? onStop : null),
          ],
        ),
      ],
    );
  }
}

class PlaybackBarLabel extends StatefulWidget {
  const PlaybackBarLabel({super.key, required this.beat});
  final ValueNotifier<double?> beat;
  @override
  State<PlaybackBarLabel> createState() => _PlaybackBarLabelState();
}

class _PlaybackBarLabelState extends State<PlaybackBarLabel> {
  int? bar;
  int? get current =>
      widget.beat.value == null ? null : (widget.beat.value! / 4).floor() + 1;
  void refresh() {
    final next = current;
    if (bar != next) setState(() => bar = next);
  }

  @override
  void initState() {
    super.initState();
    bar = current;
    widget.beat.addListener(refresh);
  }

  @override
  void didUpdateWidget(PlaybackBarLabel old) {
    super.didUpdateWidget(old);
    if (old.beat != widget.beat) {
      old.beat.removeListener(refresh);
      widget.beat.addListener(refresh);
      bar = current;
    }
  }

  @override
  void dispose() {
    widget.beat.removeListener(refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    playerStrings(context).playingBar('${bar ?? '—'}'),
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );
}

class ScoreViewport extends StatefulWidget {
  const ScoreViewport({
    super.key,
    required this.parts,
    required this.tempo,
    required this.scale,
    this.activeBeat,
    this.beatListenable,
    this.continuous = false,
    this.followPlayback = false,
  });
  final List<Part> parts;
  final double tempo, scale;
  final double? activeBeat;
  final ValueNotifier<double?>? beatListenable;
  final bool continuous;
  final bool followPlayback;
  @override
  State<ScoreViewport> createState() => _ScoreViewportState();
}

class _ScoreViewportState extends State<ScoreViewport> {
  final horizontal = ScrollController();
  final vertical = ScrollController();
  Timer? resumeTimer;
  DateTime transitionUntil = DateTime.fromMillisecondsSinceEpoch(0);
  bool userOverride = false;
  int? followedRow;

  void beatChanged() {
    if (!widget.followPlayback ||
        userOverride ||
        widget.beatListenable?.value == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => followNow());
  }

  void followNow() {
    if (!mounted || !widget.followPlayback || userOverride) return;
    final beat = widget.beatListenable?.value;
    if (beat == null || !horizontal.hasClients) return;
    const bars = 8;
    final row = (beat / (bars * 4)).floor();
    final localBeat = beat - row * bars * 4;
    final localX =
        (widget.continuous ? 0 : FullScore.left) +
        localBeat / 4 * FullScore.barWidth;
    final targetX =
        widget.continuous
            ? row * bars * FullScore.barWidth * widget.scale +
                localX * widget.scale -
                horizontal.position.viewportDimension * .5
            : localX * widget.scale -
                horizontal.position.viewportDimension * .35;
    final x = targetX.clamp(0.0, horizontal.position.maxScrollExtent);
    final now = DateTime.now();
    if (now.isBefore(transitionUntil)) return;
    final longMove =
        followedRow != row ||
        (horizontal.offset - x).abs() >
            horizontal.position.viewportDimension * .70;
    followedRow = row;
    if (longMove) {
      transitionUntil = now.add(const Duration(milliseconds: 620));
      horizontal.animateTo(
        x,
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeInOutCubic,
      );
    } else {
      // Playback updates arrive roughly every frame. Moving only a fraction of
      // the remaining distance creates a continuous camera motion instead of
      // repeatedly starting short, visibly stepped animations.
      final next = horizontal.offset + (x - horizontal.offset) * .20;
      if ((next - horizontal.offset).abs() > .05) {
        horizontal.jumpTo(next);
      }
    }
    if (!widget.continuous && vertical.hasClients) {
      final height = widget.parts.length * FullScore.staffStride + 40;
      final targetY = row * height * widget.scale;
      final y = targetY.clamp(0.0, vertical.position.maxScrollExtent);
      if (longMove) {
        vertical.animateTo(
          y,
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeInOutCubic,
        );
      } else {
        final next = vertical.offset + (y - vertical.offset) * .20;
        if ((next - vertical.offset).abs() > .05) vertical.jumpTo(next);
      }
    }
  }

  bool onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      userOverride = true;
      resumeTimer?.cancel();
    }
    if (notification is ScrollEndNotification && userOverride) {
      resumeTimer?.cancel();
      resumeTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        userOverride = false;
        followedRow = null;
        transitionUntil = DateTime.fromMillisecondsSinceEpoch(0);
        followNow();
      });
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    widget.beatListenable?.addListener(beatChanged);
  }

  @override
  void didUpdateWidget(ScoreViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.beatListenable != widget.beatListenable) {
      oldWidget.beatListenable?.removeListener(beatChanged);
      widget.beatListenable?.addListener(beatChanged);
    }
    if (!oldWidget.followPlayback && widget.followPlayback) {
      userOverride = false;
      followedRow = null;
      transitionUntil = DateTime.fromMillisecondsSinceEpoch(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => followNow());
    }
  }

  @override
  void dispose() {
    resumeTimer?.cancel();
    widget.beatListenable?.removeListener(beatChanged);
    horizontal.dispose();
    vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalBars = max(
      1,
      (widget.parts.map((p) => p.length).reduce(max) / 4).ceil(),
    );
    const bars = 8;
    final rows = (totalBars / bars).ceil();
    final width = FullScore.left + bars * FullScore.barWidth + 40;
    final height = widget.parts.length * FullScore.staffStride + 40;
    if (widget.continuous) {
      return NotificationListener<ScrollNotification>(
        onNotification: onScroll,
        child: SingleChildScrollView(
          controller: vertical,
          child: SizedBox(
            height: height * widget.scale,
            child: ListView.builder(
              controller: horizontal,
              primary: false,
              scrollDirection: Axis.horizontal,
              itemExtent: bars * FullScore.barWidth * widget.scale,
              itemCount: rows,
              itemBuilder:
                  (context, row) => ScoreTile(
                    parts: widget.parts,
                    firstBar: row * bars,
                    tempo: widget.tempo,
                    scale: widget.scale,
                    logicalSize: Size(width, height),
                    headerless: true,
                    beat: widget.beatListenable,
                  ),
            ),
          ),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: onScroll,
      child: ClipRect(
        child: SingleChildScrollView(
          controller: horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width * widget.scale,
            child: ListView.builder(
              controller: vertical,
              primary: false,
              itemExtent: height * widget.scale,
              itemCount: rows,
              itemBuilder:
                  (context, row) => ScoreTile(
                    parts: widget.parts,
                    firstBar: row * bars,
                    tempo: widget.tempo,
                    scale: widget.scale,
                    logicalSize: Size(width, height),
                    beat: widget.beatListenable,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScoreTile extends StatefulWidget {
  const ScoreTile({
    super.key,
    required this.parts,
    required this.firstBar,
    required this.tempo,
    required this.scale,
    required this.logicalSize,
    this.beat,
    this.headerless = false,
  });
  final List<Part> parts;
  final int firstBar;
  final double tempo, scale;
  final Size logicalSize;
  final ValueNotifier<double?>? beat;
  final bool headerless;
  @override
  State<ScoreTile> createState() => _ScoreTileState();
}

class _ScoreTileState extends State<ScoreTile> {
  ui.Picture? picture;
  List<List<Note>> notes = [];
  void prepare() {
    picture?.dispose();
    final recorder = ui.PictureRecorder();
    FullScore(
      widget.parts,
      widget.firstBar,
      tempo: widget.tempo,
      barsPerSystem: 8,
      headerless: widget.headerless,
    ).paint(Canvas(recorder), widget.logicalSize);
    picture = recorder.endRecording();
    notes = [
      for (final part in widget.parts)
        part.notes
            .where(
              (n) =>
                  n.beat >= widget.firstBar * 4 &&
                  n.beat < (widget.firstBar + 8) * 4,
            )
            .toList(),
    ];
  }

  @override
  void initState() {
    super.initState();
    prepare();
  }

  @override
  void didUpdateWidget(ScoreTile old) {
    super.didUpdateWidget(old);
    if (old.headerless != widget.headerless ||
        old.firstBar != widget.firstBar ||
        old.tempo != widget.tempo ||
        old.parts.length != widget.parts.length ||
        List.generate(
          widget.parts.length,
          (i) => i,
        ).any((i) => !identical(old.parts[i], widget.parts[i]))) {
      prepare();
    }
  }

  @override
  void dispose() {
    picture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        child: CustomPaint(
          painter: CachedScorePainter(
            picture!,
            widget.scale,
            headerless: widget.headerless,
          ),
        ),
      ),
      if (widget.beat != null)
        RepaintBoundary(
          child: CustomPaint(
            painter: PlaybackOverlay(
              notes,
              widget.parts,
              widget.firstBar,
              widget.scale,
              widget.beat!,
              headerless: widget.headerless,
            ),
          ),
        ),
    ],
  );
}

class CachedScorePainter extends CustomPainter {
  CachedScorePainter(this.picture, this.scale, {this.headerless = false});
  final bool headerless;
  final ui.Picture picture;
  final double scale;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.clipRect(Offset.zero & size);
    c.scale(scale);
    if (headerless) c.translate(-FullScore.left, 0);
    c.drawPicture(picture);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CachedScorePainter old) =>
      old.picture != picture ||
      old.scale != scale ||
      old.headerless != headerless;
}

class PlaybackOverlay extends CustomPainter {
  PlaybackOverlay(
    this.notes,
    this.parts,
    this.firstBar,
    this.scale,
    this.beat, {
    this.headerless = false,
  }) : super(repaint: beat);
  final List<List<Note>> notes;
  final bool headerless;
  final List<Part> parts;
  final int firstBar;
  final double scale;
  final ValueNotifier<double?> beat;
  late final rests = [
    for (final part in parts)
      part.rests
          .where((r) => r.beat >= firstBar * 4 && r.beat < (firstBar + 8) * 4)
          .toList(),
  ];
  @override
  void paint(Canvas c, Size size) {
    final current = beat.value;
    if (current == null ||
        current < firstBar * 4 ||
        current >= (firstBar + 8) * 4) {
      return;
    }
    c.save();
    c.clipRect(Offset.zero & size);
    c.scale(scale);
    if (headerless) c.translate(-FullScore.left, 0);
    final pen =
        Paint()
          ..color = Colors.red
          ..strokeWidth = 1.3;
    for (var row = 0; row < notes.length; row++) {
      for (final rest in rests[row]) {
        if (current >= rest.beat && current < rest.beat + rest.duration) {
          drawScoreRest(
            c,
            rest,
            45 + row * FullScore.staffStride,
            scoreX(parts[row], firstBar, rest.beat, headerless: headerless),
            FullScore.left +
                (rest.beat / 4 - firstBar).floor() * FullScore.barWidth,
            color: Colors.red,
          );
        }
      }
      for (final n in notes[row]) {
        if (n.grace) continue;
        if (current < n.beat || current >= n.beat + n.duration) continue;
        final x = scoreX(parts[row], firstBar, n.beat, headerless: headerless);
        final y = 65 + row * FullScore.staffStride - n.pos * 5;
        if (n.head == 'x') {
          c.drawLine(Offset(x - 4, y - 4), Offset(x + 4, y + 4), pen);
          c.drawLine(Offset(x - 4, y + 4), Offset(x + 4, y - 4), pen);
        } else {
          pen.style =
              n.dur.startsWith('Whole') || n.dur.startsWith('Half')
                  ? PaintingStyle.stroke
                  : PaintingStyle.fill;
          c.save();
          c.translate(x, y);
          c.rotate(-.25);
          c.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: n.dur.startsWith('Whole') ? 13 : 11,
              height: 7,
            ),
            pen,
          );
          c.restore();
        }
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant PlaybackOverlay old) =>
      old.headerless != headerless ||
      old.notes != notes ||
      old.scale != scale ||
      old.firstBar != firstBar ||
      old.beat != beat;
}

class ScaledScorePainter extends CustomPainter {
  ScaledScorePainter(this.score, this.scale, this.logicalSize);
  final FullScore score;
  final double scale;
  final Size logicalSize;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(scale);
    score.paint(canvas, logicalSize);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ScaledScorePainter old) =>
      old.scale != scale ||
      old.logicalSize != logicalSize ||
      score.shouldRepaint(old.score);
}

class Staff extends CustomPainter {
  Staff(this.part, this.firstBar);
  final Part part;
  final int firstBar;
  @override
  void paint(Canvas c, Size size) {
    final p =
        Paint()
          ..color = Colors.black87
          ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      c.drawLine(Offset(0, 60 + i * 10), Offset(size.width, 60 + i * 10), p);
    }
    for (var i = 0; i <= 4; i++) {
      final x = i * size.width / 4;
      c.drawLine(Offset(x, 60), Offset(x, 100), p);
      if (i < 4) {
        (TextPainter(
          text: TextSpan(
            text: '${firstBar + i + 1}',
            style: const TextStyle(color: Colors.black),
          ),
          textDirection: TextDirection.ltr,
        )..layout()).paint(c, Offset(x + 3, 20));
      }
    }
    for (final n in part.notes) {
      final beat = n.beat - firstBar * 4;
      if (beat < 0 || beat >= 16) continue;
      final x = 10 + beat / 16 * (size.width - 20), y = 80 - n.pos * 5.0;
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 9, height: 6), p);
      c.drawLine(Offset(x + 4, y), Offset(x + 4, y - 25), p);
      for (var l = 110.0; l <= y; l += 10) {
        c.drawLine(Offset(x - 7, l), Offset(x + 7, l), p);
      }
      for (var l = 50.0; l >= y; l -= 10) {
        c.drawLine(Offset(x - 7, l), Offset(x + 7, l), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant Staff old) =>
      old.part != part || old.firstBar != firstBar;
}
