import 'package:audioplayers/audioplayers.dart';
import 'storage_service.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final StorageService _storage = StorageService();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(0.4);
    await _sfxPlayer.setVolume(1.0);
    _initialized = true;
  }

  Future<void> playBGM() async {
    if (!_storage.getMusicEnabled()) return;
    if (!_initialized) await init();
    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.play(AssetSource('sounds/bg_music.mp3'));
    } catch (_) {}
  }

  Future<void> stopBGM() async {
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  Future<void> pauseBGM() async {
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeBGM() async {
    if (!_storage.getMusicEnabled()) return;
    try {
      await _bgmPlayer.resume();
    } catch (_) {}
  }

  Future<void> playTap() async => await _playSfx('sounds/tap.mp3');
  Future<void> playMatch() async => await _playSfx('sounds/match.mp3');
  Future<void> playVictory() async => await _playSfx('sounds/victory.mp3');
  Future<void> playGameOver() async => await _playSfx('sounds/gameover.mp3');
  Future<void> playCoin() async => await _playSfx('sounds/coin.mp3');

  Future<void> _playSfx(String path) async {
    if (!_storage.getSoundEnabled()) return;
    if (!_initialized) await init();
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource(path));
    } catch (_) {}
  }

  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
  }
}
