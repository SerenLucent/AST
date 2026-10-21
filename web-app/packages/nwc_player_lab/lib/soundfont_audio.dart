import 'dart:convert';
import 'dart:math';
import 'package:dart_melty_soundfont/dart_melty_soundfont.dart';
import 'main.dart' show Part;

class _Event {
  _Event(this.sample, this.channel, this.key, this.on);
  final int sample, channel, key;
  final bool on;
}

/// SoundFont PCM rendering, keeping the existing WAV playback interface.
Future<Uint8List> pianoWav(
  ByteData font,
  List<Part> parts,
  double bpm,
  double startBeat,
  Map<Part, double> gains, {
  double seconds = 30,
  bool Function()? cancelled,
}) async {
  const rate = 22050;
  final synth = Synthesizer.loadByteData(
    font,
    SynthesizerSettings(
      sampleRate: rate,
      maximumPolyphony: 128,
      enableReverbAndChorus: true,
    ),
  );
  synth.masterVolume = 0.85;
  final end = parts.map((p) => p.length).fold(startBeat, max);
  final total =
      (min(seconds, max(0.1, (end - startBeat) * 60 / bpm + 1)) * rate).ceil();
  final events = <_Event>[];
  for (var channel = 0; channel < parts.length; channel++) {
    final p = parts[channel];
    synth.processMidiMessage(
      channel: channel,
      command: 0xC0,
      data1: 0,
      data2: 0,
    );
    synth.processMidiMessage(
      channel: channel,
      command: 0xB0,
      data1: 7,
      data2: ((gains[p] ?? 1) * 127).round().clamp(0, 127),
    );
    for (final n in p.notes) {
      if (n.receivesTie) continue;
      var duration = n.duration;
      var tail = n;
      while (tail.tieTo != null) {
        tail = tail.tieTo!;
        duration += tail.duration;
      }
      if (n.dur.contains('Staccato') && n.tieTo == null) duration *= 0.5;
      final start = ((n.beat - startBeat) * 60 / bpm * rate).round();
      final finish =
          ((n.beat + duration - startBeat) * 60 / bpm * rate).round();
      if (finish <= 0 || start >= total) continue;
      events.add(_Event(max(0, start), channel, n.pitch, true));
      events.add(_Event(min(total, finish), channel, n.pitch, false));
    }
  }
  events.sort((a, b) {
    final order = a.sample.compareTo(b.sample);
    return order != 0 ? order : (a.on ? 1 : 0).compareTo(b.on ? 1 : 0);
  });
  final pcm = Float32List(total);
  var cursor = 0, processed = 0;
  Future<void> renderUntil(int target) async {
    while (cursor < target) {
      if (cancelled?.call() == true) throw StateError('재생 준비 취소');
      final count = min(2048, target - cursor);
      final left = Float32List(count), right = Float32List(count);
      synth.render(left, right);
      for (var i = 0; i < count; i++) {
        pcm[cursor + i] = (left[i] + right[i]) * 0.5;
      }
      cursor += count;
      processed += count;
      if (processed >= 8192) {
        processed = 0;
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  for (final event in events) {
    await renderUntil(event.sample);
    if (event.on) {
      synth.noteOn(channel: event.channel, key: event.key, velocity: 110);
    } else {
      synth.noteOff(channel: event.channel, key: event.key);
    }
  }
  await renderUntil(total);
  final peak = pcm.fold(0.0, (v, s) => max(v, s.abs()));
  final scale = peak > 0.95 ? 0.95 / peak : 1.0;
  final bytes = Uint8List(44 + total * 2), data = ByteData(44 + total * 2);
  void word(int at, int v) => data.setUint32(at, v, Endian.little);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  bytes.setRange(8, 16, ascii.encode('WAVEfmt '));
  bytes.setRange(36, 40, ascii.encode('data'));
  word(4, bytes.length - 8);
  word(16, 16);
  word(24, rate);
  word(28, rate * 2);
  word(40, total * 2);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  for (var i = 0; i < total; i++) {
    data.setInt16(
      44 + i * 2,
      (pcm[i] * scale * 32767).round().clamp(-32768, 32767),
      Endian.little,
    );
  }
  for (final i in [4, 16, 20, 22, 24, 28, 32, 34, 40]) {
    final length = [20, 22, 32, 34].contains(i) ? 2 : 4;
    bytes.setRange(i, i + length, data.buffer.asUint8List(i, length));
  }
  bytes.setRange(44, bytes.length, data.buffer.asUint8List(44));
  return bytes;
}
