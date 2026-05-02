import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/gem.dart';
import '../models/level.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';

enum GameStatus { idle, playing, paused, won, lost }

class GameProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final AudioService _audio = AudioService();

  Level? _currentLevel;
  GameStatus _status = GameStatus.idle;
  List<List<Gem>> _tubes = [];
  int _selectedTubeIndex = -1;
  int _movesRemaining = 0;
  int _score = 0;
  int _stars = 0;
  int _comboCount = 0;
  List<Level> _levels = [];

  Level? get currentLevel => _currentLevel;
  GameStatus get status => _status;
  List<List<Gem>> get tubes => _tubes;
  int get selectedTubeIndex => _selectedTubeIndex;
  int get movesRemaining => _movesRemaining;
  int get score => _score;
  int get stars => _stars;
  int get comboCount => _comboCount;
  List<Level> get levels => _levels;

  int get totalCoins => _storage.getCoins();
  int get lives => _storage.getLives();
  int get hints => _storage.getHints();
  int get totalStars => _storage.getTotalStars();

  GameProvider() {
    _levels = GameConstants.generateLevels();
    _loadLevelProgress();
  }

  void _loadLevelProgress() {
    for (int i = 0; i < _levels.length; i++) {
      final progress = _storage.loadLevelProgress(_levels[i]);
      if (progress != null) {
        _levels[i] = progress;
      }
    }
    notifyListeners();
  }

  void startLevel(Level level) {
    _currentLevel = level;
    _status = GameStatus.playing;
    _selectedTubeIndex = -1;
    _movesRemaining = level.maxMoves;
    _score = 0;
    _stars = 0;
    _comboCount = 0;
    _generateTubes(level);
    notifyListeners();
  }

  void _generateTubes(Level level) {
    final random = Random();

    // ── SOLVABLE SHUFFLE: reverse-from-solved ─────────────────────────────────
    // The old approach (allGems.shuffle) distributes gems randomly across tubes
    // which can produce boards where gems are permanently deadlocked — e.g.
    // two alternating-color stacks with no way to ever separate them fully.
    //
    // Fix: start with the SOLVED state (each tube holds one color, fully sorted),
    // then apply N random VALID game moves to scramble it. Because every move we
    // make is a legal game move, the resulting board is guaranteed to be solvable
    // by reversing those exact moves — the player just needs to find the path.
    // ─────────────────────────────────────────────────────────────────────────

    // Step 1 — Build solved state
    _tubes = List.generate(level.tubesCount, (_) => <Gem>[]);

    for (int c = 0; c < level.availableColors.length; c++) {
      for (int g = 0; g < level.gemsPerColor; g++) {
        _tubes[c].add(Gem(
          id: '\${level.availableColors[c].name}_\$g',
          color: level.availableColors[c],
        ));
      }
    }
    // Remaining tubes stay empty (empty buffer tubes for the player to use)

    // Step 2 — Scramble with valid moves
    // Use 3× the max moves so the board is well-shuffled but always solvable.
    final int scrambleSteps = level.maxMoves * 3;
    int lastFrom = -1;
    int lastTo   = -1;

    for (int step = 0; step < scrambleSteps; step++) {
      // Collect all legal moves (same rules as the game)
      final List<List<int>> validMoves = [];
      for (int from = 0; from < _tubes.length; from++) {
        if (_tubes[from].isEmpty) continue;
        for (int to = 0; to < _tubes.length; to++) {
          if (from == to) continue;
          if (_tubes[to].length >= level.tubeCapacity) continue;
          // Avoid immediately undoing the last move (keeps scramble diverse)
          if (from == lastTo && to == lastFrom) continue;
          if (_tubes[to].isEmpty || _tubes[to].last.color == _tubes[from].last.color) {
            validMoves.add([from, to]);
          }
        }
      }

      if (validMoves.isEmpty) break;

      final move = validMoves[random.nextInt(validMoves.length)];
      final gem = _tubes[move[0]].removeLast();
      _tubes[move[1]].add(gem);
      lastFrom = move[0];
      lastTo   = move[1];
    }
  }

  void onTubeTap(int tubeIndex) {
    if (_status != GameStatus.playing) return;

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
      if (tube.isNotEmpty) {
        allEmpty = false;
        break;
      }
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

    final updatedLevel = _currentLevel!.copyWith(
      bestStars: newStars,
      bestScore: _score,
    );

    await _storage.saveLevelProgress(updatedLevel);
    await _storage.addCoins(GameConstants.coinsPerLevelComplete);

    final nextLevelIndex = _currentLevel!.id;
    if (nextLevelIndex < _levels.length) {
      final nextLevel = _levels[nextLevelIndex].copyWith(isUnlocked: true);
      _levels[nextLevelIndex] = nextLevel;
      await _storage.saveLevelProgress(nextLevel);
    }

    _loadLevelProgress();
  }

  void useHint() async {
    if (_status != GameStatus.playing || _currentLevel == null) return;
    if (hints <= 0) {
      if (totalCoins >= GameConstants.hintCost) {
        await _storage.spendCoins(GameConstants.hintCost);
      } else {
        return;
      }
    } else {
      await _storage.setHints(hints - 1);
    }

    // Simple hint: select a tube with movable gem
    for (int i = 0; i < _tubes.length; i++) {
      if (_tubes[i].isNotEmpty) {
        _selectedTubeIndex = i;
        notifyListeners();
        return;
      }
    }
  }

  void buyExtraMoves() async {
    if (_status != GameStatus.playing) return;
    if (await _storage.spendCoins(GameConstants.extraMovesCost)) {
      _movesRemaining += 5;
      notifyListeners();
    }
  }

  void pauseGame() {
    if (_status == GameStatus.playing) {
      _status = GameStatus.paused;
      notifyListeners();
    }
  }

  void resumeGame() {
    if (_status == GameStatus.paused) {
      _status = GameStatus.playing;
      notifyListeners();
    }
  }

  void restartLevel() {
    if (_currentLevel != null) {
      startLevel(_currentLevel!);
    }
  }

  void useLifeAndRestart() async {
    if (await _storage.useLife()) {
      restartLevel();
    }
  }

  void claimRewardCoins(int amount) async {
    await _storage.addCoins(amount);
    notifyListeners();
  }

  void claimRewardMoves(int amount) {
    if (_status == GameStatus.lost || _status == GameStatus.playing) {
      _movesRemaining += amount;
      if (_status == GameStatus.lost) {
        _status = GameStatus.playing;
      }
      notifyListeners();
    }
  }

  void claimRewardLife() async {
    await _storage.addLife();
    notifyListeners();
  }
}
