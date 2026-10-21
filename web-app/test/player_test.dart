import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwc_player_lab/main.dart';
import 'package:nwc_player_lab/live_score.dart';
import 'package:nwc_player_lab/player_localizations.dart';
import 'package:nwc_player_lab/score_file_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Uint8List fixture() => File('test/fixtures/ast-practice.nwctxt').readAsBytesSync();

  test('NWCTXT opens as 8 measures, 32 notes at 100 BPM', () {
    final parts = parse(fixture());
    expect(parts, hasLength(1));
    expect(parts.single.notes, hasLength(32));
    expect(parts.single.notes.last.beat, 31);
    expect(parts.single.tempoChanges[0], 100);
  });
  test('compressed NWC opens and damaged compression is rejected', () {
    final compressed = Uint8List.fromList([...ascii.encode('[NWZ]\x00'), ...zlib.encode(fixture())]);
    expect(parse(compressed).single.notes, hasLength(32));
    compressed[compressed.length - 1] ^= 0xff;
    expect(() => parse(compressed), throwsA(isA<ScoreReadException>()));
  });
  test('EXE and oversized files rejected before reading the stream', () async {
    for (final sample in [('installer.exe', 126 * 1024 * 1024), ('large.nwc', maxScoreFileBytes + 1)]) {
      var read = false;
      final file = PlatformFile(name: sample.$1, size: sample.$2,
        readStream: Stream<List<int>>.multi((controller) { read = true; controller.close(); }));
      await expectLater(readScoreFile(file), throwsA(isA<ScoreReadException>()));
      expect(read, false);
    }
  });
  test('renamed EXE, empty file and oversized actual stream are rejected', () async {
    for (final data in [Uint8List.fromList([77, 90]), Uint8List(0), Uint8List(maxScoreFileBytes + 1)]) {
      await expectLater(readScoreFile(PlatformFile(name: 'renamed.nwc', size: 0,
        readStream: Stream.value(data))), throwsA(isA<ScoreReadException>()));
    }
  });
  test('piano SoundFont synthesizes finite non-silent samples and obeys mute', () {
    final parts = parse(fixture());
    final bytes = File('packages/nwc_player_lab/assets/soundfonts/piano.sf2').readAsBytesSync();
    final font = ByteData.sublistView(bytes);
    final score = LiveScore(font, parts, 100, 0);
    final pcm = score.render(LiveScore.sampleRate ~/ 2);
    expect(pcm.length, LiveScore.sampleRate ~/ 2);
    expect(pcm.every((v) => v.isFinite && v.abs() <= .95), true);
    expect(pcm.any((v) => v.abs() > .00001), true);
    expect(score.durationSeconds, closeTo(19.2, .001));
    expect(score.beatAtSeconds(2.4), closeTo(4, .001));
    final muted = LiveScore(font, parts, 100, 0)..volume(parts.single, 0);
    expect(muted.render(11025).every((v) => v.abs() < .00001), true);
  });
  testWidgets('example action fits iPhone-sized initial screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: NwcLocalizations.localizationsDelegates,
      supportedLocales: NwcLocalizations.supportedLocales,
      home: Scaffold(body: ScoreStartScreen(busy: false, status: '',
        onOpen: () {}, onExample: () => opened = true)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('예제 악보 열기'));
    expect(opened, true);
    expect(tester.takeException(), isNull);
  });
}
