import 'dart:async';
import 'package:flutter/foundation.dart';
import 'game_event.dart';

enum GuardianMood {
  neutral,
  watching,
  happy,
  excited,
  frustrated,
  nervous,
  celebrating,
  sad,
}

/// Translates [GameEvent]s into [GuardianMood] and excitement values.
class CharacterReactionManager extends ChangeNotifier {
  GuardianMood _mood = GuardianMood.neutral;
  double _excitement = 0.0;
  bool _blinkTrigger = false;

  GuardianMood get mood => _mood;
  double get excitement => _excitement;
  bool get blinkTrigger => _blinkTrigger;

  StreamSubscription<GameEvent>? _sub;
  Timer? _resetTimer;
  Timer? _blinkTimer;
  Timer? _excitementDecayTimer;

  CharacterReactionManager() {
    _startPeriodicBlink();
    _startExcitementDecay();
  }

  void subscribe(Stream<GameEvent> events) {
    _sub?.cancel();
    _sub = events.listen(_handle);
  }

  void _handle(GameEvent event) {
    _resetTimer?.cancel();
    switch (event) {
      case GameEvent.playerSelectedGem:
        _setMood(GuardianMood.watching);
        break;
      case GameEvent.validMove:
      case GameEvent.goodMove:
        _excitement = (_excitement + 0.12).clamp(0.0, 1.0);
        _setMood(GuardianMood.happy);
        _scheduleReset(1600);
        break;
      case GameEvent.invalidMove:
      case GameEvent.badMove:
        _excitement = (_excitement - 0.05).clamp(0.0, 1.0);
        _setMood(GuardianMood.frustrated);
        _scheduleReset(1400);
        break;
      case GameEvent.comboStarted:
        _excitement = (_excitement + 0.20).clamp(0.0, 1.0);
        _setMood(GuardianMood.excited);
        _scheduleReset(2000);
        break;
      case GameEvent.comboContinued:
        _excitement = (_excitement + 0.15).clamp(0.0, 1.0);
        _setMood(GuardianMood.excited);
        _scheduleReset(2000);
        break;
      case GameEvent.tubeCompleted:
        _excitement = (_excitement + 0.30).clamp(0.0, 1.0);
        _setMood(GuardianMood.excited);
        _scheduleReset(2400);
        break;
      case GameEvent.levelNearCompletion:
        _setMood(GuardianMood.nervous);
        break;
      case GameEvent.levelCompleted:
        _excitement = 1.0;
        _setMood(GuardianMood.celebrating);
        _scheduleReset(4000);
        break;
      case GameEvent.gameOver:
        _excitement = 0.0;
        _setMood(GuardianMood.sad);
        _scheduleReset(3000);
        break;
      case GameEvent.playerIdle:
        if (_mood == GuardianMood.watching || _mood == GuardianMood.neutral) {
          _setMood(GuardianMood.neutral);
        }
        break;
    }
  }

  void _setMood(GuardianMood mood) {
    if (_mood == mood) return;
    _mood = mood;
    notifyListeners();
  }

  void _scheduleReset(int ms) {
    _resetTimer = Timer(Duration(milliseconds: ms), () {
      if (_mood != GuardianMood.celebrating && _mood != GuardianMood.sad) {
        _setMood(GuardianMood.neutral);
      }
    });
  }

  void _startPeriodicBlink() {
    void schedule() {
      final interval = 3000 + ((1.0 - _excitement) * 2000).toInt();
      _blinkTimer = Timer(Duration(milliseconds: interval), () {
        _blinkTrigger = !_blinkTrigger;
        notifyListeners();
        schedule();
      });
    }
    schedule();
  }

  void _startExcitementDecay() {
    _excitementDecayTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_excitement > 0) {
        _excitement = (_excitement - 0.04).clamp(0.0, 1.0);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _resetTimer?.cancel();
    _blinkTimer?.cancel();
    _excitementDecayTimer?.cancel();
    super.dispose();
  }
}
