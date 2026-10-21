import 'main.dart' show Part;

/// Piecewise beat/time conversion; notes crossing a tempo mark span both rates.
class TempoMap {
  TempoMap(List<Part> parts, double initialBpm) {
    final raw = <double, double>{};
    for (final part in parts) {
      for (final entry in part.tempoChanges.entries) {
        raw.putIfAbsent(entry.key, () => entry.value);
      }
      for (final entry in part.fermataPauses.entries) {
        pauses.update(
          entry.key,
          (value) => entry.value > value ? entry.value : value,
          ifAbsent: () => entry.value,
        );
      }
    }
    final factor = initialBpm / (raw[0] ?? initialBpm);
    rates[0] = initialBpm;
    for (final beat in raw.keys.toList()..sort()) {
      rates[beat] = raw[beat]! * factor;
    }
  }
  final rates = <double, double>{};
  final pauses = <double, double>{};
  double bpmAt(double beat) {
    var bpm = rates[0]!;
    for (final entry in rates.entries) {
      if (entry.key > beat) break;
      bpm = entry.value;
    }
    return bpm;
  }

  double secondsAt(double beat) {
    var previous = 0.0, bpm = rates[0]!, seconds = 0.0;
    for (final entry in rates.entries) {
      if (entry.key > beat) break;
      seconds += (entry.key - previous) * 60 / bpm;
      previous = entry.key;
      bpm = entry.value;
    }
    seconds += (beat - previous) * 60 / bpm;
    for (final entry in pauses.entries) {
      if (entry.key <= beat) seconds += entry.value;
    }
    return seconds;
  }

  double beatAt(double seconds) {
    var previous = 0.0, bpm = rates[0]!, elapsed = 0.0;
    final boundaries =
        {...rates.keys, ...pauses.keys}.where((b) => b > 0).toList()..sort();
    for (final boundary in boundaries) {
      final duration = (boundary - previous) * 60 / bpm;
      if (elapsed + duration > seconds) {
        return previous + (seconds - elapsed) * bpm / 60;
      }
      elapsed += duration;
      previous = boundary;
      final pause = pauses[boundary] ?? 0;
      if (seconds < elapsed + pause) {
        return boundary - .000001;
      }
      elapsed += pause;
      bpm = rates[boundary] ?? bpm;
    }
    return previous + (seconds - elapsed) * bpm / 60;
  }
}
