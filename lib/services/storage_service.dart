import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/level.dart';
import '../utils/constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── Coins ────────────────────────────────────────────────────────────────
  int getCoins() => _prefs?.getInt('coins') ?? GameConstants.startingCoins;
  Future<void> setCoins(int coins) async => await _prefs?.setInt('coins', coins);
  Future<void> addCoins(int amount) async => await setCoins(getCoins() + amount);
  Future<bool> spendCoins(int amount) async {
    final current = getCoins();
    if (current >= amount) {
      await setCoins(current - amount);
      return true;
    }
    return false;
  }

  // ─── Lives ────────────────────────────────────────────────────────────────
  int getLives() => _prefs?.getInt('lives') ?? 5;
  Future<void> setLives(int lives) async => await _prefs?.setInt('lives', lives);
  Future<void> addLife() async {
    final current = getLives();
    if (current < 5) await setLives(current + 1);
  }
  Future<bool> useLife() async {
    final current = getLives();
    if (current > 0) {
      await setLives(current - 1);
      await setLastLifeUsedTime(DateTime.now().millisecondsSinceEpoch);
      return true;
    }
    return false;
  }

  int getLastLifeUsedTime() => _prefs?.getInt('last_life_used') ?? 0;
  Future<void> setLastLifeUsedTime(int time) async =>
      await _prefs?.setInt('last_life_used', time);

  // ─── Level Progress ───────────────────────────────────────────────────────
  String _levelKey(int levelId) => 'level_$levelId';

  Future<void> saveLevelProgress(Level level) async {
    final data = {
      'unlocked': level.isUnlocked,
      'bestStars': level.bestStars,
      'bestScore': level.bestScore,
    };
    await _prefs?.setString(_levelKey(level.id), jsonEncode(data));
  }

  Level? loadLevelProgress(Level baseLevel) {
    final raw = _prefs?.getString(_levelKey(baseLevel.id));
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return baseLevel.copyWith(
        isUnlocked: data['unlocked'] ?? baseLevel.isUnlocked,
        bestStars: data['bestStars'],
        bestScore: data['bestScore'],
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Settings ─────────────────────────────────────────────────────────────
  bool getSoundEnabled() => _prefs?.getBool('sound_enabled') ?? true;
  Future<void> setSoundEnabled(bool value) async =>
      await _prefs?.setBool('sound_enabled', value);

  bool getMusicEnabled() => _prefs?.getBool('music_enabled') ?? true;
  Future<void> setMusicEnabled(bool value) async =>
      await _prefs?.setBool('music_enabled', value);

  bool getVibrationEnabled() => _prefs?.getBool('vibration_enabled') ?? true;
  Future<void> setVibrationEnabled(bool value) async =>
      await _prefs?.setBool('vibration_enabled', value);

  int getHighScore() => _prefs?.getInt('high_score') ?? 0;
  Future<void> setHighScore(int score) async =>
      await _prefs?.setInt('high_score', score);

  int getTotalStars() {
    int total = 0;
    for (int i = 1; i <= 100; i++) {
      final raw = _prefs?.getString('level_$i');
      if (raw != null) {
        try {
          final data = jsonDecode(raw);
          total += (data['bestStars'] ?? 0) as int;
        } catch (_) {}
      }
    }
    return total;
  }

  // ─── Remove Ads — Tiered with Expiry ──────────────────────────────────────
  //
  //  Tier strings: 'none' | 'day' | 'weekend' | 'month'
  //  Expiry is stored as epoch milliseconds.
  //  isAdsRemoved() returns true only while the timer hasn't expired.

  Future<void> setRemoveAdsTier(String tier, int durationMs) async {
    final expiry = DateTime.now().millisecondsSinceEpoch + durationMs;
    await _prefs?.setString('remove_ads_tier', tier);
    await _prefs?.setInt('remove_ads_expiry', expiry);
  }

  bool isAdsRemoved() {
    final tier = _prefs?.getString('remove_ads_tier') ?? 'none';
    if (tier == 'none') return false;
    final expiry = _prefs?.getInt('remove_ads_expiry') ?? 0;
    return DateTime.now().millisecondsSinceEpoch < expiry;
  }

  String getRemoveAdsTier() =>
      _prefs?.getString('remove_ads_tier') ?? 'none';

  int getRemoveAdsExpiry() =>
      _prefs?.getInt('remove_ads_expiry') ?? 0;

  /// Legacy helper kept for AdMobService compatibility.
  bool getRemoveAdsPurchased() => isAdsRemoved();
  Future<void> setRemoveAdsPurchased(bool value) async =>
      await _prefs?.setBool('remove_ads', value);

  // ─── Hints ────────────────────────────────────────────────────────────────
  int getHints() => _prefs?.getInt('hints') ?? GameConstants.startingHints;
  Future<void> setHints(int hints) async =>
      await _prefs?.setInt('hints', hints);
  Future<void> addHints(int count) async =>
      await setHints(getHints() + count);

  // ─── Reset ────────────────────────────────────────────────────────────────
  Future<void> resetAll() async => await _prefs?.clear();
}
