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
    await _migrateLegacyProgressIfNeeded();
  }

  /// One-time migration: computes O(1) star count and highest-unlocked-level
  /// from the old per-level keys so the new infinite-level system has a
  /// correct starting point for existing players. Skipped on every launch
  /// after the first because 'total_stars' will already exist.
  Future<void> _migrateLegacyProgressIfNeeded() async {
    if (_prefs?.containsKey('total_stars') ?? false) return;
    int total = 0;
    int highest = 1;
    for (int i = 1; i <= 100; i++) {
      final raw = _prefs?.getString('level_$i');
      if (raw == null) continue;
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        total += (data['bestStars'] ?? 0) as int;
        if ((data['unlocked'] == true) && i > highest) highest = i;
      } catch (_) {}
    }
    await _prefs?.setInt('total_stars', total);
    await _prefs?.setInt('highest_unlocked_level', highest);
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

  // O(1) counter — kept in sync by _migrateLegacyProgressIfNeeded on first
  // launch and addToTotalStars on every level completion thereafter.
  int getTotalStars() => _prefs?.getInt('total_stars') ?? 0;

  Future<void> addToTotalStars(int delta) async {
    if (delta <= 0) return;
    await _prefs?.setInt('total_stars', getTotalStars() + delta);
  }

  // ─── Endless progression ──────────────────────────────────────────────────
  int getHighestUnlockedId() =>
      _prefs?.getInt('highest_unlocked_level') ?? 1;

  Future<void> setHighestUnlockedId(int id) async =>
      await _prefs?.setInt('highest_unlocked_level', id);

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

  // ─── Daily Bonus ──────────────────────────────────────────────────────────
  // Rolling 24-hour cooldown from last claim — not a calendar-day reset,
  // which would still let someone claim at 11:59 pm and again at midnight.

  Future<void> claimDailyBonus() async => await _prefs?.setInt(
      'daily_bonus_last_claimed', DateTime.now().millisecondsSinceEpoch);

  int _dailyBonusLastClaimed() =>
      _prefs?.getInt('daily_bonus_last_claimed') ?? 0;

  bool canClaimDailyBonus() {
    final last = _dailyBonusLastClaimed();
    if (last == 0) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed >= GameConstants.dailyBonusCooldownMs;
  }

  Duration getDailyBonusTimeRemaining() {
    final last = _dailyBonusLastClaimed();
    if (last == 0) return Duration.zero;
    final readyAt = last + GameConstants.dailyBonusCooldownMs;
    final remaining = readyAt - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? Duration(milliseconds: remaining) : Duration.zero;
  }

  // ─── Tutorial ─────────────────────────────────────────────────────────────
  bool hasTutorialCompleted() =>
      _prefs?.getBool('tutorial_completed') ?? false;
  Future<void> markTutorialCompleted() async =>
      await _prefs?.setBool('tutorial_completed', true);

  // ─── Hints ────────────────────────────────────────────────────────────────
  int getHints() => _prefs?.getInt('hints') ?? GameConstants.startingHints;
  Future<void> setHints(int hints) async =>
      await _prefs?.setInt('hints', hints);
  Future<void> addHints(int count) async =>
      await setHints(getHints() + count);

  // ─── Reset ────────────────────────────────────────────────────────────────
  Future<void> resetAll() async => await _prefs?.clear();
}
