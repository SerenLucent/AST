import 'dart:math';
import 'package:dart_melty_soundfont/dart_melty_soundfont.dart';
import 'main.dart' show Part;
import 'tempo_map.dart';
import 'repeat_plan.dart';

class ScoreEvent {
  ScoreEvent(this.frame, this.channel, this.key, this.on, [this.velocity = 110])
    : program = null;
  ScoreEvent.program(this.frame, this.channel, this.program)
    : key = 0,
      on = false,
      velocity = 0;
  final int velocity;
  final int frame, channel, key;
  final bool on;
  final int? program;
}

/// MIDI events are dispatched at sample boundaries, independent of UI timers.
class LiveScore {
  LiveScore(
    ByteData font,
    this.parts,
    this.bpm,
    this.startBeat, {
    double? endBeat,
    double tailSeconds = 2,
  }) : synth = Synthesizer.loadByteData(
         font,
         SynthesizerSettings(
           sampleRate: sampleRate,
           maximumPolyphony: 128,
           enableReverbAndChorus: true,
         ),
       ) {
    synth.masterVolume = 0.85;
    tempoMap = TempoMap(parts, bpm);
    var elapsed = 0.0;
    final plan =
        endBeat == null
            ? repeatPlan(parts, startBeat)
            : [PlaybackSpan(startBeat, max(startBeat, endBeat))];
    for (final span in plan) {
      final until =
          elapsed + tempoMap.secondsAt(span.to) - tempoMap.secondsAt(span.from);
      timeline.add((span, elapsed, until));
      elapsed = until;
    }
    durationSeconds = elapsed;
    endFrame =
        (elapsed * sampleRate).ceil() + (sampleRate * tailSeconds).round();
    for (var channel = 0; channel < parts.length; channel++) {
      synth.processMidiMessage(
        channel: channel,
        command: 0xC0,
        data1: 0,
        data2: 0,
      );
      for (final segment in timeline) {
        final span = segment.$1;
        final origin = tempoMap.secondsAt(span.from) - segment.$2;
        var program = 0;
        for (final change in parts[channel].instrumentChanges.entries) {
          if (change.key <= span.from + .000001) program = change.value;
        }
        events.add(
          ScoreEvent.program(
            (segment.$2 * sampleRate).round(),
            channel,
            program,
          ),
        );
        for (final change in parts[channel].instrumentChanges.entries) {
          if (change.key <= span.from + .000001 ||
              change.key >= span.to - .000001) {
            continue;
          }
          final at =
              segment.$2 +
              tempoMap.secondsAt(change.key) -
              tempoMap.secondsAt(span.from);
          events.add(
            ScoreEvent.program(
              (at * sampleRate).round(),
              channel,
              change.value,
            ),
          );
        }
        for (final n in parts[channel].notes) {
          if (n.beat >= span.to - .000001) {
            continue;
          }
          if ((n.receivesTie && (n.beat - span.from).abs() > .000001) ||
              n.muted) {
            continue;
          }
          var duration = n.duration, tail = n;
          while (tail.tieTo != null) {
            tail = tail.tieTo!;
            duration += tail.duration;
          }
          duration = min(duration, span.to - n.beat);
          if (n.beat + duration <= span.from + .000001) continue;
          if (n.dur.contains('Staccato') && n.tieTo == null) duration *= 0.5;
          final graceGroup =
              n.grace
                  ? parts[channel].notes
                      .where((other) => other.grace && other.beat == n.beat)
                      .toList()
                  : const [];
          final graceOffset =
              n.grace
                  ? (graceGroup.length - graceGroup.indexOf(n)) * .055
                  : 0.0;
          final onset = max(
            segment.$2,
            tempoMap.secondsAt(n.beat) - origin - graceOffset,
          );
          final from = (onset * sampleRate).round();
          final until =
              ((n.grace
                          ? onset + .05
                          : tempoMap.secondsAt(n.beat + duration) - origin) *
                      sampleRate)
                  .round();
          if (until <= 0) continue;
          var velocity = 110;
          for (final dynamic in parts[channel].dynamics.entries) {
            if (dynamic.key <= n.beat) velocity = dynamic.value;
          }
          events.add(
            ScoreEvent(max(0, from), channel, n.pitch, true, velocity),
          );
          events.add(ScoreEvent(until, channel, n.pitch, false));
        }
      }
    }
    events.sort((a, b) {
      final result = a.frame.compareTo(b.frame);
      if (result != 0) return result;
      int priority(ScoreEvent event) =>
          event.program != null ? 0 : (event.on ? 2 : 1);
      return priority(a).compareTo(priority(b));
    });
  }
  static const sampleRate = 22050;
  final List<Part> parts;
  final double bpm, startBeat;
  late final double durationSeconds;
  final Synthesizer synth;
  late final TempoMap tempoMap;
  final timeline = <(PlaybackSpan, double, double)>[];
  double beatAtSeconds(double seconds) {
    for (final segment in timeline) {
      if (seconds < segment.$3) {
        return tempoMap.beatAt(
          tempoMap.secondsAt(segment.$1.from) + max(0, seconds - segment.$2),
        );
      }
    }
    return timeline.isEmpty ? startBeat : timeline.last.$1.to;
  }

  final events = <ScoreEvent>[];
  late final int endFrame;
  int frame = 0, eventIndex = 0;
  bool get ended => frame >= endFrame;

  void volume(Part part, double value) {
    final channel = parts.indexOf(part);
    if (channel < 0) return;
    synth.processMidiMessage(
      channel: channel,
      command: 0xB0,
      data1: 7,
      data2: (value * 127).round().clamp(0, 127),
    );
  }

  Float32List render(int requestedFrames) {
    final count = min(requestedFrames, max(0, endFrame - frame));
    final mono = Float32List(count);
    var offset = 0;
    while (offset < count) {
      while (eventIndex < events.length && events[eventIndex].frame <= frame) {
        final event = events[eventIndex++];
        if (event.program != null) {
          synth.processMidiMessage(
            channel: event.channel,
            command: 0xC0,
            data1: event.program!,
            data2: 0,
          );
        } else if (event.on) {
          synth.noteOn(
            channel: event.channel,
            key: event.key,
            velocity: event.velocity,
          );
        } else {
          synth.noteOff(channel: event.channel, key: event.key);
        }
      }
      final next =
          eventIndex < events.length ? events[eventIndex].frame : endFrame;
      final step = min(1024, min(count - offset, next - frame));
      final left = Float32List(step), right = Float32List(step);
      synth.render(left, right);
      for (var i = 0; i < step; i++) {
        mono[offset + i] = ((left[i] + right[i]) * 0.5).clamp(-0.95, 0.95);
      }
      frame += step;
      offset += step;
    }
    return mono;
  }
}
