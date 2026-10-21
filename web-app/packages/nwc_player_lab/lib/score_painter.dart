import 'dart:math';
import 'package:flutter/material.dart';
import 'main.dart' show Part, Note;
import 'tempo_map.dart';

// NWC Spacer Width values are engraving units, not logical screen pixels.
// Composer uses them to reserve room inside the current measure.
const double nwcSpacerPixelsPerUnit = .4;

void drawScoreRest(
  Canvas c,
  Note rest,
  double top,
  double dx,
  double barStart, {
  Color color = Colors.black,
}) {
  final pen = Paint()..color = color;
  if (rest.dur.startsWith('Whole') || rest.dur.startsWith('Half')) {
    c.drawRect(
      Rect.fromLTWH(
        rest.dur.startsWith('Whole')
            ? barStart + FullScore.barWidth / 2
            : dx - 5,
        top + (rest.dur.startsWith('Whole') ? 10 : 16),
        12,
        4,
      ),
      pen,
    );
  } else {
    final code =
        rest.duration >= 1
            ? '\uE4E5'
            : rest.duration >= .5
            ? '\uE4E6'
            : '\uE4E7';
    final glyph = TextPainter(
      text: TextSpan(
        text: code,
        style: TextStyle(fontFamily: 'ScoreMusic', fontSize: 40, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(
      c,
      Offset(
        dx - 5,
        top +
            20 -
            glyph.computeDistanceToActualBaseline(TextBaseline.alphabetic),
      ),
    );
  }
  if (rest.dur.contains('Dotted')) {
    c.drawCircle(Offset(dx + 13, top + 17), 1.8, pen);
  }
}

double scoreX(Part part, int firstBar, double beat, {bool headerless = false}) {
  final bar = (beat / 4).floor();
  final signature = part.keyChanges[bar * 4.0];
  final reserve =
      (part.timeChanges.containsKey(bar * 4.0) && bar > 0 ? 24.0 : 0.0) +
      (signature != null && (bar > firstBar || headerless)
          ? signature.split(',').where((s) => s.isNotEmpty).length * 12.0 + 14
          : 0.0);
  final barSpacers = part.spacers.where(
    (spacer) => (spacer.$1 / 4).floor() == bar,
  );
  final totalSpacerWidth = barSpacers.fold(
    0.0,
    (total, spacer) => total + spacer.$2 * nwcSpacerPixelsPerUnit,
  );
  final spacerOffset = barSpacers
      .where((spacer) => spacer.$1 <= beat + .000001)
      .fold(0.0, (total, spacer) => total + spacer.$2 * nwcSpacerPixelsPerUnit);
  final rhythmicWidth = max(
    40.0,
    FullScore.barWidth -
        reserve -
        (headerless ? 40 : 0) -
        totalSpacerWidth -
        (totalSpacerWidth > 0 ? 16.0 : 0.0),
  );
  final barLeft = FullScore.left + (bar - firstBar) * FullScore.barWidth;
  final position =
      barLeft +
      20 +
      reserve +
      (beat - bar * 4) / 4 * rhythmicWidth +
      spacerOffset;
  // Every measure is a hard engraving cell. Malformed or unusually large
  // authored spacing must never push an event into its neighbouring measure.
  return position
      .clamp(barLeft + 8.0, barLeft + FullScore.barWidth - 16.0)
      .toDouble();
}

List<int> keyPositions(String signature, String clef) {
  const flats = {'B': 0, 'E': 3, 'A': -1, 'D': 2, 'G': -2, 'C': 1, 'F': -3};
  const sharps = {'F': 4, 'C': 1, 'G': 5, 'D': 2, 'A': -1, 'E': 3, 'B': 0};
  final positions = [
    for (final token in signature.split(','))
      if (token.length == 2 && '#b'.contains(token[1]))
        ((token[1] == 'b' ? flats : sharps)[token[0]] ?? 0) -
            (clef == 'Bass'
                ? 2
                : clef == 'Alto'
                ? 1
                : clef == 'Tenor'
                ? -1
                : 0),
  ];
  return [
    for (final pos in positions) clef == 'Tenor' && pos > 4 ? pos - 7 : pos,
  ];
}

void drawClef(
  Canvas canvas,
  String clef,
  double x,
  double top, {
  double size = 40,
}) {
  final glyph = switch (clef) {
    'Bass' => '\uE062',
    'Alto' || 'Tenor' => '\uE05C',
    'Percussion' => '\uE069',
    _ => '\uE050',
  };
  final anchor = switch (clef) {
    'Bass' || 'Tenor' => 10.0,
    'Alto' || 'Percussion' => 20.0,
    _ => 30.0,
  };
  final painter = TextPainter(
    text: TextSpan(
      text: glyph,
      style: TextStyle(
        fontFamily: 'ScoreMusic',
        fontSize: size,
        color: Colors.black,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(
      x,
      top +
          anchor -
          painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
    ),
  );
}

class FullScore extends CustomPainter {
  FullScore(
    this.parts,
    this.firstBar, {
    this.tempo = 157,
    this.barsPerSystem = 4,
    this.activeBeat,
    this.headerless = false,
  });
  final int barsPerSystem;
  final bool headerless;
  final double? activeBeat;
  final double tempo;
  final List<Part> parts;
  final int firstBar;
  // NWC Composer expands content-heavy measures substantially. Keep a
  // generous fixed minimum so sixteenth-note beams and Korean lyrics do not
  // collide even before authored Spacer values are applied.
  static const left = 210.0, barWidth = 380.0, staffStride = 110.0;
  Part? paintingPart;
  double x(double beat) =>
      scoreX(paintingPart!, firstBar, beat, headerless: headerless);
  void text(
    Canvas c,
    String value,
    double dx,
    double dy, {
    double size = 13,
    bool italic = false,
  }) {
    final music = value.runes.any(
      (r) => r > 0x1D000 || (r >= 0x2669 && r <= 0x266F),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.black,
          fontSize: size,
          fontWeight:
              music
                  ? FontWeight.w400
                  : italic
                  ? FontWeight.w600
                  : FontWeight.w600,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          fontFamily:
              value.runes.any(
                    (r) => r > 0x1D000 || (r >= 0x2669 && r <= 0x266F),
                  )
                  ? 'ScoreMusic'
                  : 'ScoreText',
          fontFamilyFallback: const ['ScoreText', 'ScoreMusic'],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final position = Offset(dx, dy - (music ? size : 0));
    painter.paint(c, position);
  }

  void accidental(Canvas c, Note note, double dx, double dy) {
    final glyph =
        const {'#': '♯', 'b': '♭', 'n': '♮', 'x': '𝄪', 'v': '𝄫'}[note
            .accidental];
    if (glyph == null) return;
    final painter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 22,
          fontWeight: FontWeight.w400,
          fontFamily: 'ScoreMusic',
          fontFamilyFallback: ['ScoreText'],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // An accidental belongs to the note on its right. Keep its right edge close
    // to that notehead so it cannot read as a mark attached to the prior note.
    painter.paint(c, Offset(dx - painter.width - 5, dy - painter.height / 2));
  }

  @override
  void paint(Canvas c, Size size) {
    c.drawColor(Colors.white, BlendMode.src);
    final pen =
        Paint()
          ..color = Colors.black
          ..strokeWidth = 1.2;
    final outline =
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3;
    for (var b = 0; b < barsPerSystem; b++) {
      text(c, '${firstBar + b + 1}', left + b * barWidth, 8);
    }
    if (firstBar == 0 && parts.isNotEmpty) {
      text(
        c,
        '${parts.first.tempoSymbolAt(0)} = ${(tempo / parts.first.tempoUnitAt(0)).round()}',
        70,
        10,
      );
    }
    for (var row = 0; row < parts.length; row++) {
      final part = parts[row], top = 45 + row * staffStride, middle = top + 20;
      paintingPart = part;
      if (row == 0) {
        for (final change in TempoMap(parts, tempo).rates.entries) {
          if (change.key > 0 &&
              change.key >= firstBar * 4 &&
              change.key < (firstBar + barsPerSystem) * 4) {
            text(
              c,
              '${part.tempoSymbolAt(change.key)} = ${(change.value / part.tempoUnitAt(change.key)).round()}',
              left + (change.key / 4 - firstBar) * barWidth + 4,
              top - 28,
            );
          }
        }
      }
      if (!headerless) {
        text(c, part.label, 4, top + 5, size: 15);
        text(c, part.name, 4, top + 27, size: 12);
      }
      for (var line = 0; line < 5; line++) {
        c.drawLine(
          Offset(headerless ? left : 60, top + line * 10),
          Offset(left + barsPerSystem * barWidth, top + line * 10),
          pen,
        );
      }
      if (!headerless) {
        drawClef(c, part.clefAt(firstBar * 4.0), 65, top);
        final octave = part.octaveAt(firstBar * 4.0);
        if (octave.isNotEmpty) {
          text(
            c,
            '8',
            80,
            octave.contains('Up') ? top - 20 : top + 41,
            size: 12,
          );
        }
      }
      void drawKey(String signature, String clef, double startX) {
        final tokens =
            signature
                .split(',')
                .where((t) => t.length == 2 && '#b'.contains(t[1]))
                .toList();
        final positions = keyPositions(signature, clef);
        for (var i = 0; i < tokens.length; i++) {
          final glyph = TextPainter(
            text: TextSpan(
              text: tokens[i][1] == 'b' ? '\uE260' : '\uE262',
              style: const TextStyle(
                fontFamily: 'ScoreMusic',
                fontSize: 40,
                color: Colors.black,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final baseline = glyph.computeDistanceToActualBaseline(
            TextBaseline.alphabetic,
          );
          glyph.paint(
            c,
            Offset(startX + i * 12, middle - positions[i] * 5 - baseline),
          );
        }
      }

      if (!headerless) {
        drawKey(part.keyAt(firstBar * 4.0), part.clefAt(firstBar * 4.0), 105);
      }
      for (final change in part.clefChanges.entries) {
        if (change.key > 0 &&
            change.key >= firstBar * 4 &&
            change.key < (firstBar + barsPerSystem) * 4) {
          drawClef(c, change.value, x(change.key) - 26, top, size: 32);
          final octave = part.octaveAt(change.key);
          if (octave.isNotEmpty) {
            text(
              c,
              '8',
              x(change.key) - 16,
              octave.contains('Up') ? top - 20 : top + 41,
              size: 12,
            );
          }
        }
      }
      for (final change in part.keyChanges.entries) {
        if ((change.key > firstBar * 4 ||
                (headerless && change.key == firstBar * 4)) &&
            change.key < (firstBar + barsPerSystem) * 4) {
          drawKey(
            change.value,
            part.clefAt(change.key),
            left + (change.key / 4 - firstBar) * barWidth + 8,
          );
        }
      }
      if (firstBar == 0) {
        if (part.timeSignature == 'Common' ||
            part.timeSignature == 'AllaBreve') {
          text(c, 'C', 185, top + 7, size: 23);
          if (part.timeSignature == 'AllaBreve') {
            c.drawLine(Offset(194, top + 4), Offset(194, top + 37), pen);
          }
        } else {
          final values = part.timeSignature.split('/');
          text(c, values.first, 185, top - 3, size: 20);
          text(
            c,
            values.length == 2 ? values.last : '4',
            185,
            top + 18,
            size: 20,
          );
        }
      }
      for (final change in part.timeChanges.entries) {
        if (change.key <= 0 ||
            change.key < firstBar * 4 ||
            change.key >= (firstBar + barsPerSystem) * 4) {
          continue;
        }
        final dx = left + (change.key / 4 - firstBar) * barWidth + 4;
        if (change.value == 'Common' || change.value == 'AllaBreve') {
          text(c, 'C', dx, top + 7, size: 23);
          if (change.value == 'AllaBreve') {
            c.drawLine(Offset(dx + 9, top + 4), Offset(dx + 9, top + 37), pen);
          }
        } else {
          final values = change.value.split('/');
          if (values.length == 2) {
            text(c, values[0], dx, top - 3, size: 20);
            text(c, values[1], dx, top + 18, size: 20);
          }
        }
      }
      for (var b = 0; b <= barsPerSystem; b++) {
        final style = part.barStyles[(firstBar + b) * 4.0];
        c.drawLine(
          Offset(left + b * barWidth, top),
          Offset(left + b * barWidth, top + 40),
          pen,
        );
        if (style == 'Double') {
          c.drawLine(
            Offset(left + b * barWidth - 4, top),
            Offset(left + b * barWidth - 4, top + 40),
            pen,
          );
        }
        if (style != null &&
            (style.contains('Repeat') || style == 'SectionClose')) {
          final bx = left + b * barWidth;
          final close = style.contains('Close');
          c.drawLine(
            Offset(bx + (close ? -5 : 5), top),
            Offset(bx + (close ? -5 : 5), top + 40),
            Paint()
              ..color = Colors.black
              ..strokeWidth = 3,
          );
          if (style.contains('Repeat')) {
            for (final yy in [middle - 5, middle + 5]) {
              c.drawCircle(Offset(bx + (close ? -12 : 12), yy), 2, pen);
            }
          }
        }
      }
      for (final ending in part.endings.entries) {
        var end = part.length;
        for (final next in part.endings.keys) {
          if (next > ending.key && next < end) end = next;
        }
        for (final boundary in part.barStyles.entries) {
          if (boundary.key > ending.key &&
              boundary.key < end &&
              boundary.value.contains('Close')) {
            end = boundary.key;
          }
        }
        final start = max(ending.key, firstBar * 4.0);
        final finish = min(end, (firstBar + barsPerSystem) * 4.0);
        if (start >= finish) continue;
        final sx = left + (start / 4 - firstBar) * barWidth;
        final ex = left + (finish / 4 - firstBar) * barWidth;
        c.drawLine(Offset(sx, top - 25), Offset(ex, top - 25), pen);
        if (start == ending.key) {
          c.drawLine(Offset(sx, top - 25), Offset(sx, top - 8), pen);
          text(c, '${ending.value}.', sx + 4, top - 24, size: 14);
        }
      }
      for (final annotation in part.texts.where(
        (t) =>
            (t.beat - (t.rightAligned ? .000001 : 0)) >= firstBar * 4 &&
            (t.beat - (t.rightAligned ? .000001 : 0)) <
                (firstBar + barsPerSystem) * 4,
      )) {
        final annotationBar = (annotation.beat / 4).floor();
        c.save();
        c.clipRect(
          Rect.fromLTWH(
            left + (annotationBar - firstBar) * barWidth + 1,
            top - 40,
            barWidth - 2,
            staffStride + 40,
          ),
        );
        if (annotation.value == 'To Coda 𝄌') {
          final dx =
              annotation.rightAligned
                  ? left + (annotation.beat / 4 - firstBar) * barWidth - 85
                  : x(annotation.beat) - 15;
          final dy = middle - annotation.pos * 5 - 15;
          text(c, 'To Coda', dx, dy, size: 14, italic: true);
          text(c, '𝄌', dx + 60, dy + 18, size: 26);
          c.restore();
          continue;
        }
        text(
          c,
          annotation.value,
          annotation.rightAligned
              ? left + (annotation.beat / 4 - firstBar) * barWidth - 85
              : x(annotation.beat) - 15,
          middle - annotation.pos * 5 - 15,
          size: 14,
          italic: annotation.font.contains('Italic'),
        );
        c.restore();
      }
      final notes =
          part.notes
              .where(
                (n) =>
                    n.beat >= firstBar * 4 &&
                    n.beat < (firstBar + barsPerSystem) * 4,
              )
              .toList();
      final chords = <double, List<Note>>{};
      for (final note in part.notes) {
        if (note.grace) continue;
        (chords[note.beat] ??= []).add(note);
      }
      List<Note> chord(Note n) =>
          (chords[n.beat] ?? [n])
              .where((head) => head.stemGroup == n.stemGroup)
              .toList();
      bool stemUp(Note n) {
        if (n.opts.contains('Stem=Down')) return false;
        if (n.opts.contains('Stem=Up')) return true;
        final group = chord(n);
        return group.map((other) => other.pos).reduce((a, b) => a + b) /
                group.length <=
            0;
      }

      final beamGroup = <Note>[];
      void beam() {
        if (beamGroup.length >= 2) {
          final up = stemUp(beamGroup.first);
          final ys = beamGroup.expand(chord).map((n) => middle - n.pos * 5);
          final beamY = up ? ys.reduce(min) - 30 : ys.reduce(max) + 30;
          final thick =
              Paint()
                ..color = Colors.black
                ..strokeWidth = 4;
          for (final n in beamGroup) {
            final dx = x(n.beat) + (up ? 5 : -5);
            final headYs = chord(n).map((head) => middle - head.pos * 5);
            c.drawLine(
              Offset(dx, up ? headYs.reduce(max) : headYs.reduce(min)),
              Offset(dx, beamY),
              pen,
            );
          }
          c.drawLine(
            Offset(x(beamGroup.first.beat) + (up ? 5 : -5), beamY),
            Offset(x(beamGroup.last.beat) + (up ? 5 : -5), beamY),
            thick,
          );
          for (var j = 0; j + 1 < beamGroup.length; j++) {
            final a = beamGroup[j], b = beamGroup[j + 1];
            for (final level in [3, 4]) {
              final types = level == 3 ? ['32nd', '64th'] : ['64th'];
              if (types.any((t) => a.dur.startsWith(t)) &&
                  types.any((t) => b.dur.startsWith(t))) {
                c.drawLine(
                  Offset(
                    x(a.beat) + (up ? 5 : -5),
                    beamY + (up ? 1 : -1) * 7 * (level - 1),
                  ),
                  Offset(
                    x(b.beat) + (up ? 5 : -5),
                    beamY + (up ? 1 : -1) * 7 * (level - 1),
                  ),
                  thick,
                );
              }
            }
            if (['16th', '32nd', '64th'].any((t) => a.dur.startsWith(t)) &&
                ['16th', '32nd', '64th'].any((t) => b.dur.startsWith(t))) {
              c.drawLine(
                Offset(x(a.beat) + (up ? 5 : -5), beamY + (up ? 7 : -7)),
                Offset(x(b.beat) + (up ? 5 : -5), beamY + (up ? 7 : -7)),
                thick,
              );
            }
          }
        }
        beamGroup.clear();
      }

      for (var index = 0; index < notes.length; index++) {
        final n = notes[index], dx = x(n.beat), dy = middle - n.pos * 5;
        final noteBar = (n.beat / 4).floor();
        c.save();
        c.clipRect(
          Rect.fromLTWH(
            left + (noteBar - firstBar) * barWidth + 1,
            top - 40,
            barWidth - 2,
            staffStride + 40,
          ),
        );
        if (n.grace) {
          final group =
              part.notes
                  .where((other) => other.grace && other.beat == n.beat)
                  .toList();
          final gx = dx - 15 * (group.length - group.indexOf(n));
          c.drawOval(
            Rect.fromCenter(center: Offset(gx, dy), width: 7, height: 4.5),
            pen,
          );
          c.drawLine(Offset(gx + 3, dy), Offset(gx + 3, dy - 22), pen);
          if (group.length > 1) {
            c.drawLine(
              Offset(
                dx - 15 * group.length + 3,
                middle - group.first.pos * 5 - 22,
              ),
              Offset(dx - 12, middle - group.first.pos * 5 - 22),
              pen,
            );
          }
          c.restore();
          continue;
        }
        if (n.dur.contains('Triplet=First')) {
          final end =
              notes
                  .skip(index + 1)
                  .where(
                    (other) =>
                        !other.grace && other.dur.contains('Triplet=End'),
                  )
                  .firstOrNull;
          if (end != null) {
            final above = stemUp(n);
            final ex = x(end.beat), y = above ? top - 10 : top + 53;
            c.drawLine(Offset(dx, y + (above ? 5 : -5)), Offset(dx, y), pen);
            c.drawLine(Offset(dx, y), Offset(ex, y), pen);
            c.drawLine(Offset(ex, y), Offset(ex, y + (above ? 5 : -5)), pen);
            text(
              c,
              '3',
              (dx + ex) / 2 - 4,
              above ? y - 17 : y + 1,
              size: 13,
              italic: true,
            );
          }
        }
        final whole = n.dur.startsWith('Whole'),
            hollow = whole || n.dur.startsWith('Half');
        final percussion = n.head == 'x';
        final active =
            activeBeat != null &&
            activeBeat! >= n.beat &&
            activeBeat! < n.beat + n.duration;
        final headPen =
            Paint()
              ..color = active ? Colors.red : Colors.black
              ..strokeWidth = 1.2;
        final headOutline =
            Paint()
              ..color = active ? Colors.red : Colors.black
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.3;
        if (percussion) {
          c.drawLine(Offset(dx - 4, dy - 4), Offset(dx + 4, dy + 4), headPen);
          c.drawLine(Offset(dx - 4, dy + 4), Offset(dx + 4, dy - 4), headPen);
        } else {
          c.save();
          c.translate(dx, dy);
          c.rotate(-0.25);
          c.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: whole ? 13 : 11,
              height: 7,
            ),
            hollow ? headOutline : headPen,
          );
          c.restore();
        }
        for (var l = top - 10; l >= dy; l -= 10) {
          c.drawLine(Offset(dx - 9, l), Offset(dx + 9, l), pen);
        }
        for (var l = top + 50; l <= dy; l += 10) {
          c.drawLine(Offset(dx - 9, l), Offset(dx + 9, l), pen);
        }
        if (n.accidental.isNotEmpty) {
          accidental(c, n, dx, dy);
        }
        if (n.dur.contains('Dotted')) {
          c.drawCircle(Offset(dx + 11, dy - 3), 1.8, pen);
        }
        if (n.dur.contains('Staccato')) {
          c.drawCircle(Offset(dx, dy + (stemUp(n) ? 12 : -12)), 1.8, pen);
        }
        if (n.dur.contains('Accent')) {
          final stacked =
              n.dur.contains('Staccato') || n.dur.contains('Tenuto');
          final distance = stacked ? 22.0 : 15.0;
          final ay = dy + (stemUp(n) ? distance : -distance);
          c.drawLine(Offset(dx - 5, ay - 3), Offset(dx + 5, ay), pen);
          c.drawLine(Offset(dx + 5, ay), Offset(dx - 5, ay + 3), pen);
        }
        if (n.dur.contains('Tenuto')) {
          final ay = dy + (stemUp(n) ? 15 : -15);
          c.drawLine(Offset(dx - 5, ay), Offset(dx + 5, ay), pen);
        }
        final group = chord(n);
        final leader = identical(group.first, n);
        final up = stemUp(n);
        final headYs = group.map((head) => middle - head.pos * 5);
        final stemStart = up ? headYs.reduce(max) : headYs.reduce(min);
        final stemEnd = up ? headYs.reduce(min) - 30 : headYs.reduce(max) + 30;
        if (!whole && !n.opts.contains('Beam') && leader) {
          c.drawLine(
            Offset(dx + (up ? 5 : -5), stemStart),
            Offset(dx + (up ? 5 : -5), stemEnd),
            pen,
          );
          if (!n.opts.contains('Beam') && n.duration < 1) {
            final side = up ? -1.0 : 1.0;
            final stemX = dx + (up ? 5 : -5);
            final path =
                Path()
                  ..moveTo(stemX, stemEnd)
                  ..quadraticBezierTo(
                    stemX + 18,
                    stemEnd - side * 15,
                    stemX + 5,
                    stemEnd - side * 21,
                  );
            c.drawPath(path, outline);
            if (n.dur.startsWith('16th')) {
              c.drawPath(path.shift(Offset(0, -side * 7)), outline);
            }
          }
        }
        if (leader) {
          if (n.opts.contains('Beam=First')) beam();
          if (n.opts.contains('Beam')) {
            if (beamGroup.isNotEmpty &&
                (beamGroup.first.beat / 4).floor() != (n.beat / 4).floor()) {
              beam();
            }
            beamGroup.add(n);
          } else {
            beam();
          }
          if (n.opts.contains('Beam=End')) beam();
        }
        if (n.lyricLines.isEmpty && n.lyric.isNotEmpty) {
          text(c, n.lyric, dx - 6, top + 68, size: 13);
        }
        for (final verse in n.lyricLines.entries) {
          if (verse.value.isNotEmpty) {
            text(
              c,
              verse.value,
              dx - 6,
              top + 68 + (verse.key - 1) * 17,
              size: 13,
            );
          }
        }
        c.restore();
      }
      // Connections are resolved over the entire staff, not the visible system.
      // This preserves ties crossing both bar lines and four-bar line breaks.
      for (final source in part.notes) {
        for (final target in [source.tieTo, source.slurTo].whereType<Note>()) {
          final from = firstBar * 4.0, until = (firstBar + barsPerSystem) * 4.0;
          if (target.beat < from || source.beat >= until) continue;
          final startX = source.beat < from ? left : x(source.beat) + 6;
          final endX =
              target.beat >= until
                  ? left + barsPerSystem * barWidth
                  : x(target.beat) - 6;
          final startY = middle - source.pos * 5;
          final endY = middle - target.pos * 5;
          final kind = source.tieTo == target ? 'Tie' : 'Slur';
          final above =
              source.opts.contains('$kind=Upward') ||
              (!source.opts.contains('$kind=Downward') && !stemUp(source));
          final side = above ? -1.0 : 1.0;
          final base = above ? min(startY, endY) : max(startY, endY);
          final curve =
              Path()
                ..moveTo(startX, startY + side * 8)
                ..quadraticBezierTo(
                  (startX + endX) / 2,
                  base + side * 22,
                  endX,
                  endY + side * 8,
                );
          c.drawPath(curve, outline);
        }
      }
      beam();
      for (final r in part.rests.where(
        (n) =>
            n.beat >= firstBar * 4 && n.beat < (firstBar + barsPerSystem) * 4,
      )) {
        final dx = x(r.beat);
        final restBar = (r.beat / 4).floor();
        c.save();
        c.clipRect(
          Rect.fromLTWH(
            left + (restBar - firstBar) * barWidth + 1,
            top - 10,
            barWidth - 2,
            staffStride,
          ),
        );
        drawScoreRest(
          c,
          r,
          top,
          dx,
          left + (r.beat / 4 - firstBar).floor() * barWidth,
        );
        c.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant FullScore old) =>
      old.headerless != headerless ||
      old.parts != parts ||
      old.firstBar != firstBar ||
      old.tempo != tempo ||
      old.barsPerSystem != barsPerSystem ||
      old.activeBeat != activeBeat;
}
