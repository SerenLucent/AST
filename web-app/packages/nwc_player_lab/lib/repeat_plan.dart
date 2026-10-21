import 'dart:math';
import 'main.dart' show Part;

class PlaybackSpan {
  PlaybackSpan(this.from, this.to);
  final double from;
  double to;
}

/// Expand explicit bar repeats and numbered endings, keeping source positions.
List<PlaybackSpan> repeatPlan(List<Part> parts, double startBeat) {
  final styles = <double, String>{}, endings = <double, String>{};
  final flows = <double, Set<String>>{};
  var end = startBeat;
  for (final p in parts) {
    styles.addAll(p.barStyles);
    endings.addAll(p.endings);
    for (final entry in p.flowChanges.entries) {
      flows.putIfAbsent(entry.key, () => <String>{}).addAll(entry.value);
    }
    end = max(end, p.length);
  }
  final pairs = <double, double>{};
  final stack = <double>[];
  for (final beat in styles.keys.toList()..sort()) {
    final style = styles[beat]!;
    if (style.contains('RepeatClose')) {
      pairs[beat] = stack.isEmpty ? 0 : stack.removeLast();
    }
    if (style.contains('RepeatOpen')) stack.add(beat);
  }
  final boundaries =
      {0.0, end, ...styles.keys, ...endings.keys, ...flows.keys}.toList()
        ..sort();
  final passes = <double, int>{};
  final spans = <PlaybackSpan>[];
  var cursor = 0.0, started = startBeat <= 0;
  var dalSegnoTaken = false, alCodaTaken = false;
  final segnos =
      flows.entries
          .where((e) => e.value.contains('Segno'))
          .map((e) => e.key)
          .toList()
        ..sort();
  final codas =
      flows.entries
          .where((e) => e.value.contains('Coda'))
          .map((e) => e.key)
          .toList()
        ..sort();
  final segno = segnos.isEmpty ? null : segnos.first;
  final coda = codas.isEmpty ? null : codas.first;
  for (var guard = 0; cursor < end && guard < 10000; guard++) {
    final flow = flows[cursor] ?? const <String>{};
    if (!dalSegnoTaken &&
        (flow.contains('DSalCoda') || flow.contains('DalSegno')) &&
        segno != null) {
      dalSegnoTaken = true;
      cursor = segno;
      continue;
    }
    if (!dalSegnoTaken && flow.contains('DCalCoda')) {
      dalSegnoTaken = true;
      cursor = 0;
      continue;
    }
    if (dalSegnoTaken &&
        !alCodaTaken &&
        flow.contains('ToCoda') &&
        coda != null) {
      alCodaTaken = true;
      cursor = coda;
      continue;
    }
    if (pairs.containsKey(cursor)) {
      final pass = passes[cursor] ?? 1;
      if (pass == 1) {
        passes[cursor] = 2;
        cursor = pairs[cursor]!;
      }
    }
    final ending = endings[cursor];
    if (ending != null && ending.split(',').contains('1')) {
      final closes =
          pairs.keys.where((c) => c > cursor && pairs[c]! <= cursor).toList()
            ..sort();
      if (closes.isNotEmpty && passes[closes.first] == 2) {
        cursor = closes.first;
        continue;
      }
    }
    final next = boundaries.firstWhere(
      (b) => b > cursor + .000001,
      orElse: () => end,
    );
    var from = cursor;
    if (!started && startBeat >= cursor && startBeat < next) {
      started = true;
      from = startBeat;
    }
    if (started && next > from) {
      if (spans.isNotEmpty && (spans.last.to - from).abs() < .000001) {
        spans.last.to = next;
      } else {
        spans.add(PlaybackSpan(from, next));
      }
    }
    cursor = next;
  }
  // A repeat at the end boundary still needs its second pass.
  if (pairs.containsKey(end) && passes[end] == null) {
    final start = pairs[end]!;
    final firstEnding =
        endings.keys
            .where(
              (b) =>
                  b >= start && b < end && endings[b]!.split(',').contains('1'),
            )
            .toList()
          ..sort();
    spans.add(
      PlaybackSpan(
        max(startBeat, start),
        firstEnding.isEmpty ? end : firstEnding.first,
      ),
    );
  }
  return spans.where((s) => s.to > s.from).toList();
}
