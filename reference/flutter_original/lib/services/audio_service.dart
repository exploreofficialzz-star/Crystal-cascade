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
  bool _bgmActive = false; // tracks whether BGM should be playing

  Future<void> init() async {
    if (_initialized) return;

    // BGM: use 'gain' so the OS audio focus is properly released when
    // the app goes to background — this works together with the
    // AppLifecycleState observer in main.dart to fully stop music on minimize.
    await _bgmPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.gain,
          isSpeakerphoneOn: false,
          stayAwake: false,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );

    // SFX: transient focus — grabs focus briefly then releases back to BGM
    await _sfxPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.gainTransient,
          isSpeakerphoneOn: false,
          stayAwake: false,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );

    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(0.4);
    await _sfxPlayer.setVolume(1.0);

    _initialized = true;
  }

  Future<void> playBGM() async {
    if (!_storage.getMusicEnabled()) return;
    if (!_initialized) await init();
    _bgmActive = true;
    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.play(AssetSource('sounds/bg_music.mp3'));
    } catch (_) {}
  }

  Future<void> stopBGM() async {
    _bgmActive = false;
    try { await _bgmPlayer.stop(); } catch (_) {}
  }

  Future<void> pauseBGM() async {
    try { await _bgmPlayer.pause(); } catch (_) {}
  }

  /// Only resumes if music was actively playing — won't restart from shop/settings
  Future<void> resumeBGM() async {
    if (!_bgmActive) return;
    if (!_storage.getMusicEnabled()) return;
    try { await _bgmPlayer.resume(); } catch (_) {}
  }

  Future<void> playTap()      async => _playSfx('sounds/tap.mp3');
  Future<void> playMatch()    async => _playSfx('sounds/match.mp3');
  Future<void> playVictory()  async => _playSfx('sounds/victory.mp3');
  Future<void> playGameOver() async => _playSfx('sounds/gameover.mp3');
  Future<void> playCoin()     async => _playSfx('sounds/coin.mp3');

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
