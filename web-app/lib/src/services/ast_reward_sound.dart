import 'package:audioplayers/audioplayers.dart';

abstract class AstRewardSound {
  Future<void> prepare();
  Future<void> play();
  Future<void> stop();
  Future<void> dispose();
}

/// Cosmetic audio must never affect the server receipt or block the UI.
class CoinStackRewardSound implements AstRewardSound {
  AudioPlayer? _player;
  Future<void>? _ready;
  bool _disposed = false;
  bool _loaded = false;
  int _generation = 0;

  @override
  Future<void> prepare() => _ready ??= _load();

  Future<void> _load() async {
    if (_disposed) return;
    try {
      final player = _player = AudioPlayer();
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.sonification,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
      if (_disposed) return;
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(.55);
      await player.setSource(AssetSource('sounds/ast_coin_collect.wav'));
      _loaded = !_disposed;
    } catch (_) {
      _loaded = false;
    }
  }

  @override
  Future<void> play() async {
    final generation = _generation;
    await prepare();
    if (_disposed || !_loaded || generation != _generation) return;
    try {
      await _player?.resume();
    } catch (_) {
      // Muted/unavailable audio must not undo a successfully saved reward.
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    try {
      await _player?.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    await _ready;
    try {
      await _player?.dispose();
    } catch (_) {}
  }
}
