import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'main.dart' show Part;
import 'live_score.dart';
import 'playback_notification.dart';

class LivePlayer {
  SoLoud? _audio;
  SoLoud get audio => _audio ??= SoLoud.instance;
  LiveScore? score;
  AudioSource? source;
  SoundHandle? handle;
  Timer? timer;
  int generation = 0, reportedMillis = -1000;
  bool playing = false, paused = false, dataEnded = false;
  bool looping = false;
  double? loopEndBeat;
  ByteData? _loopFont;
  List<Part>? _loopParts;
  double _loopBpm = 0, _loopStartBeat = 0;
  Map<Part, double> _loopGains = const {};
  Set<int> _loopEnabled = const {};
  String title = 'NWC Player';
  void Function(double seconds, bool ended)? onProgress;
  void Function(Object error)? onError;
  double beatAt(double seconds) {
    final live = score;
    if (live == null) return 0;
    final position =
        looping && live.durationSeconds > 0
            ? seconds % live.durationSeconds
            : seconds;
    return live.beatAtSeconds(position);
  }

  Future<void> play(
    ByteData font,
    List<Part> parts,
    double bpm,
    double startBeat,
    Map<Part, double> gains,
    Set<int> enabled, {
    String title = 'NWC Player',
    double? endBeat,
    bool loop = false,
  }) async {
    final stopping = stop();
    final request = generation;
    await stopping;
    // A back/stop action while old audio is being torn down cancels this play
    // request too; do not start a new generation after that action completes.
    if (request != generation) return;
    this.title = title;
    if (!audio.isInitialized) {
      await audio.init().timeout(const Duration(seconds: 15));
    }
    if (request != generation) return;
    looping = loop;
    loopEndBeat = endBeat;
    _loopFont = font;
    _loopParts = parts;
    _loopBpm = bpm;
    _loopStartBeat = startBeat;
    _loopGains = Map.of(gains);
    _loopEnabled = Set.of(enabled);
    final next = LiveScore(
      font,
      parts,
      bpm,
      startBeat,
      endBeat: endBeat,
      tailSeconds: loop ? 0 : 2,
    );
    for (var i = 0; i < parts.length; i++) {
      next.volume(parts[i], enabled.contains(i) ? (gains[parts[i]] ?? 1) : 0);
    }
    score = next;
    final stream = audio.setBufferStream(
      maxBufferSizeBytes: 22050 * 4 * 2,
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0.1,
      sampleRate: LiveScore.sampleRate,
      channels: Channels.mono,
      format: BufferType.f32le,
    );
    source = stream;
    dataEnded = false;
    reportedMillis = -1000;
    playing = true;
    _fill();
    final started = await audio.play(stream);
    if (request != generation) {
      await audio.stop(started);
      return;
    }
    handle = started;
    onProgress?.call(0, false);
    timer = Timer.periodic(const Duration(milliseconds: 25), (_) => _tick());
    unawaited(PlaybackNotification.show(title));
  }

  void _fill() {
    final stream = source, live = score;
    if (stream == null || live == null || dataEnded) return;
    // Only a quarter-second of future sound is generated, never a whole song.
    final queued = audio.getBufferSize(stream) ~/ 4;
    final desired = (LiveScore.sampleRate * 0.25).round();
    if (queued < desired) {
      final pcm = live.render(desired - queued);
      if (pcm.isNotEmpty) {
        audio.addAudioDataStream(stream, pcm.buffer.asUint8List());
      }
    }
    if (live.ended && looping) {
      final next = LiveScore(
        _loopFont!,
        _loopParts!,
        _loopBpm,
        _loopStartBeat,
        endBeat: loopEndBeat,
        tailSeconds: 0,
      );
      for (var i = 0; i < _loopParts!.length; i++) {
        next.volume(
          _loopParts![i],
          _loopEnabled.contains(i) ? (_loopGains[_loopParts![i]] ?? 1) : 0,
        );
      }
      score = next;
      dataEnded = false;
      _fill();
      return;
    }
    if (live.ended) {
      dataEnded = true;
      audio.setDataIsEnded(stream);
    }
  }

  void _tick() {
    if (!playing || paused || source == null) return;
    try {
      _fill();
      final milliseconds = audio.getStreamTimeConsumed(source!).inMilliseconds;
      final done = dataEnded && audio.getBufferSize(source!) == 0;
      if (done || milliseconds - reportedMillis >= 33) {
        reportedMillis = milliseconds;
        onProgress?.call(milliseconds / 1000, done);
      }
      if (done) unawaited(stop());
    } catch (error) {
      unawaited(stop());
      onError?.call(error);
    }
  }

  void volume(Part part, double value) => score?.volume(part, value);

  void pause() {
    if (handle == null || !playing) return;
    paused = !paused;
    audio.setPause(handle!, paused);
    unawaited(PlaybackNotification.show(title, paused: paused));
  }

  Future<void> stop() async {
    unawaited(PlaybackNotification.clear());
    generation++;
    playing = false;
    paused = false;
    timer?.cancel();
    timer = null;
    final oldHandle = handle, oldSource = source;
    handle = null;
    source = null;
    score = null;
    looping = false;
    if (oldHandle != null) await audio.stop(oldHandle);
    if (oldSource != null) await audio.disposeSource(oldSource);
  }
}
