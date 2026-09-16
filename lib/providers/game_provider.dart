import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/gem.dart';
import '../models/level.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';

enum GameStatus { idle, playing, paused, won, lost }

/// Result returned by useHint() so the UI can respond appropriately.
enum HintResult {
  used,        // hint applied successfully (used stored hint)
  usedCoins,   // hint applied, coins deducted
  noCoins,     // out of hints AND not enough coins → show monetization wall
  noHints,     // no hints available at all → show monetization wall
}

class GameProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final AudioService _audio = AudioService();

  Level? _currentLevel;
  GameStatus _status = GameStatus.idle;
  List<List<Gem>> _tubes = [];
  int _selectedTubeIndex = -1;
  int _hintDestinationIndex = -1;   // tube the hint arrow points TO
  int _movesRemaining = 0;
  int _score = 0;
  int _stars = 0;
  int _comboCount = 0;

  // ── Endless level system ──────────────────────────────────────────────────
  // Levels are generated on demand (GameConstants.generateLevel) and cached
  // here as they're visited/unlocked. There is no fixed final level.
  final Map<int, Level> _levelCache = {};
  int _highestUnlockedId = 1;

  Timer? _hintClearTimer;

  Level? get currentLevel => _currentLevel;
  GameStatus get status => _status;
  List<List<Gem>> get tubes => _tubes;
  int get selectedTubeIndex => _selectedTubeIndex;
  int get hintDestinationIndex => _hintDestinationIndex;
  int get movesRemaining => _movesRemaining;
  int get score => _score;
  int get stars => _stars;
  int get comboCount => _comboCount;
  int get highestUnlockedId => _highestUnlockedId;

  int get totalCoins => _storage.getCoins();
  int get lives => _storage.getLives();
  int get hints => _storage.getHints();
  int get totalStars => _storage.getTotalStars();

  GameProvider() {
    _highestUnlockedId = _storage.getHighestUnlockedId();
  }

  /// Returns the level for [id], generating it fresh (and merging any saved
  /// progress) the first time it's requested, then serving from cache.
  Level levelAt(int id) {
    final cached = _levelCache[id];
    if (cached != null) return cached;
    final base = GameConstants.generateLevel(id);
    final withProgress = _storage.loadLevelProgress(base) ?? base;
    _levelCache[id] = withProgress;
    return withProgress;
  }

  void startLevel(Level level) {
    _currentLevel = level;
    _status = GameStatus.playing;
    _selectedTubeIndex = -1;
    _hintDestinationIndex = -1;
    _movesRemaining = level.maxMoves;
    _score = 0;
    _stars = 0;
    _comboCount = 0;
    _hintClearTimer?.cancel();
    _generateTubes(level);
    notifyListeners();
  }

  void _generateTubes(Level level) {
    _tubes = [];
    final random = Random();
    final List<Gem> allGems = [];
    for (final color in level.availableColors) {
      for (int i = 0; i < level.gemsPerColor; i++) {
        allGems.add(Gem(id: '${color.name}_$i', color: color));
      }
    }
    allGems.shuffle(random);
    for (int t = 0; t < level.tubesCount; t++) {
      _tubes.add([]);
    }
    int gemIndex = 0;
    for (int t = 0; t < level.tubesCount - 1; t++) {
      for (int g = 0; g < level.tubeCapacity && gemIndex < allGems.length; g++) {
        _tubes[t].add(allGems[gemIndex++]);
      }
    }
  }

  void onTubeTap(int tubeIndex) {
    if (_status != GameStatus.playing) return;

    // Clear hint glow on any tap
    _hintClearTimer?.cancel();
    _hintDestinationIndex = -1;

    if (_selectedTubeIndex == -1) {
      if (_tubes[tubeIndex].isNotEmpty) {
        _selectedTubeIndex = tubeIndex;
        _audio.playTap();
        notifyListeners();
      }
    } else if (_selectedTubeIndex == tubeIndex) {
      _selectedTubeIndex = -1;
      notifyListeners();
    } else {
      _moveGem(_selectedTubeIndex, tubeIndex);
    }
  }

  void _moveGem(int fromIndex, int toIndex) {
    if (_tubes[fromIndex].isEmpty) return;
    if (_tubes[toIndex].length >= (_currentLevel?.tubeCapacity ?? 4)) return;

    final gem = _tubes[fromIndex].last;
    if (_tubes[toIndex].isNotEmpty && _tubes[toIndex].last.color != gem.color) {
      _selectedTubeIndex = -1;
      notifyListeners();
      return;
    }

    _tubes[fromIndex].removeLast();
    _tubes[toIndex].add(gem);
    _movesRemaining--;
    _selectedTubeIndex = -1;
    _score += 10;

    _audio.playTap();
    _checkMatches(toIndex);
    _checkWinCondition();
    notifyListeners();
  }

  void _checkMatches(int tubeIndex) {
    final tube = _tubes[tubeIndex];
    if (tube.length < 3) return;

    final lastColor = tube.last.color;
    int matchCount = 1;
    for (int i = tube.length - 2; i >= 0; i--) {
      if (tube[i].color == lastColor) {
        matchCount++;
      } else {
        break;
      }
    }

    if (matchCount >= 3) {
      _comboCount++;
      final bonus = _comboCount * 50;
      _score += bonus;
      for (int i = 0; i < matchCount && tube.isNotEmpty; i++) {
        tube.removeLast();
      }
      _audio.playMatch();
      _storage.addCoins(GameConstants.coinsPerStar);
    }
  }

  void _checkWinCondition() {
    bool allEmpty = true;
    for (final tube in _tubes) {
      if (tube.isNotEmpty) { allEmpty = false; break; }
    }
    if (allEmpty) {
      _status = GameStatus.won;
      _stars = _currentLevel?.calculateStars(_movesRemaining) ?? 1;
      _score += _movesRemaining * 20;
      _audio.playVictory();
      _saveProgress();
      return;
    }
    if (_movesRemaining <= 0) {
      _status = GameStatus.lost;
      _audio.playGameOver();
      notifyListeners();
    }
  }

  void _saveProgress() async {
    if (_currentLevel == null) return;
    final currentBestStars = _currentLevel!.bestStars ?? 0;
    final newStars = _stars > currentBestStars ? _stars : currentBestStars;
    final updatedLevel = _currentLevel!.copyWith(bestStars: newStars, bestScore: _score);
    _levelCache[updatedLevel.id] = updatedLevel;
    await _storage.saveLevelProgress(updatedLevel);
    await _storage.addCoins(GameConstants.coinsPerLevelComplete);

    final starDelta = newStars - currentBestStars;
    if (starDelta > 0) await _storage.addToTotalStars(starDelta);

    // Unlock the next level — always, since progression has no ceiling.
    final nextId = updatedLevel.id + 1;
    final nextLevel = levelAt(nextId);
    if (!nextLevel.isUnlocked) {
      final unlocked = nextLevel.copyWith(isUnlocked: true);
      _levelCache[nextId] = unlocked;
      await _storage.saveLevelProgress(unlocked);
    }
    if (nextId > _highestUnlockedId) {
      _highestUnlockedId = nextId;
      await _storage.setHighestUnlockedId(nextId);
    }

    notifyListeners();
  }

  // ─── Hint System ──────────────────────────────────────────────────────────
  //
  //  Priority order:
  //   1. Has hints stored  → use 1, show smart move highlight
  //   2. No hints, has coins (≥ hintCost) → spend coins, show hint (usedCoins)
  //   3. Nothing → return noCoins / noHints so UI shows monetization dialog

  Future<HintResult> useHint() async {
    if (_status != GameStatus.playing || _currentLevel == null) {
      return HintResult.noHints;
    }

    if (hints > 0) {
      await _storage.setHints(hints - 1);
      _applySmartHint();
      notifyListeners();
      return HintResult.used;
    }

    // No stored hints — try spending coins
    if (totalCoins >= GameConstants.hintCost) {
      await _storage.spendCoins(GameConstants.hintCost);
      _applySmartHint();
      notifyListeners();
      return HintResult.usedCoins;
    }

    // Completely broke — tell UI to show the monetization wall
    return HintResult.noCoins;
  }

  /// Finds the best valid move and highlights source + destination tubes.
  void _applySmartHint() {
    final capacity = _currentLevel?.tubeCapacity ?? 4;

    for (int from = 0; from < _tubes.length; from++) {
      if (_tubes[from].isEmpty) continue;
      final topGem = _tubes[from].last;

      for (int to = 0; to < _tubes.length; to++) {
        if (from == to) continue;
        final dest = _tubes[to];
        if (dest.length >= capacity) continue;

        final isValidMove = dest.isEmpty || dest.last.color == topGem.color;
        if (isValidMove) {
          _selectedTubeIndex = from;
          _hintDestinationIndex = to;
          _scheduleHintClear();
          return;
        }
      }
    }

    // Fallback: just highlight first non-empty tube
    for (int i = 0; i < _tubes.length; i++) {
      if (_tubes[i].isNotEmpty) {
        _selectedTubeIndex = i;
        _hintDestinationIndex = -1;
        _scheduleHintClear();
        return;
      }
    }
  }

  void _scheduleHintClear() {
    _hintClearTimer?.cancel();
    _hintClearTimer = Timer(GameConstants.hintGlowDuration, () {
      _hintDestinationIndex = -1;
      notifyListeners();
    });
  }

  /// Add hints (from ad reward or IAP). Notifies listeners.
  void addHints(int count) async {
    await _storage.addHints(count);
    notifyListeners();
  }

  /// Buy a single hint with coins (called from game screen coin path).
  Future<bool> buyHintWithCoins() async {
    if (totalCoins >= GameConstants.hintCost) {
      await _storage.spendCoins(GameConstants.hintCost);
      await _storage.addHints(1);
      notifyListeners();
      return true;
    }
    return false;
  }

  // ─── Extra Moves ──────────────────────────────────────────────────────────
  void buyExtraMoves() async {
    if (_status != GameStatus.playing) return;
    if (await _storage.spendCoins(GameConstants.extraMovesCost)) {
      _movesRemaining += 5;
      notifyListeners();
    }
  }

  // ─── Extra Tube ───────────────────────────────────────────────────────────
  // A stuck board sometimes just needs more space, not more moves — this
  // adds one empty tube. Capped at +2 above the level's original tube count
  // per attempt so it stays a rescue, not a way to trivialize hard boards.
  bool get canAddExtraTube =>
      _status == GameStatus.playing &&
      _currentLevel != null &&
      _tubes.length < _currentLevel!.tubesCount + 2;

  void _addTube() {
    _tubes.add([]);
    _audio.playTap();
    notifyListeners();
  }

  Future<bool> buyExtraTube() async {
    if (!canAddExtraTube) return false;
    if (await _storage.spendCoins(GameConstants.extraTubeCost)) {
      _addTube();
      return true;
    }
    return false;
  }

  /// Grants a free tube after a rewarded ad — no coin spend.
  void addFreeExtraTube() {
    if (!canAddExtraTube) return;
    _addTube();
  }

  // ─── Misc ─────────────────────────────────────────────────────────────────
  void pauseGame() {
    if (_status == GameStatus.playing) { _status = GameStatus.paused; notifyListeners(); }
  }

  void resumeGame() {
    if (_status == GameStatus.paused) { _status = GameStatus.playing; notifyListeners(); }
  }

  void restartLevel() {
    if (_currentLevel != null) startLevel(_currentLevel!);
  }

  void useLifeAndRestart() async {
    if (await _storage.useLife()) {
      restartLevel();
      final missingLives = 5 - lives;
      if (missingLives > 0) {
        NotificationService().scheduleLifeRegen(missingLives);
      }
    }
  }

  void claimRewardCoins(int amount) async {
    await _storage.addCoins(amount);
    notifyListeners();
  }

  void claimRewardMoves(int amount) {
    if (_status == GameStatus.lost || _status == GameStatus.playing) {
      _movesRemaining += amount;
      if (_status == GameStatus.lost) _status = GameStatus.playing;
      notifyListeners();
    }
  }

  void claimRewardLife() async {
    await _storage.addLife();
    notifyListeners();
  }

  @override
  void dispose() {
    _hintClearTimer?.cancel();
    super.dispose();
  }
}
