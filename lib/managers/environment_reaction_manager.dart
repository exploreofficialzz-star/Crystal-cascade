import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'game_event.dart';

/// Translates [GameEvent]s into environment-level intensity values.
/// Consumed by [LivingBackgroundWidget] for ambient reactions.
class EnvironmentReactionManager extends ChangeNotifier {
  double _particleIntensity = 0.3;
  double _lightIntensity    = 0.3;
  bool   _bloomActive       = false;

  double get particleIntensity => _particleIntensity;
  double get lightIntensity    => _lightIntensity;
  bool   get bloomActive       => _bloomActive;

  StreamSubscription<GameEvent>? _sub;
  Timer? _decayTimer;

  void subscribe(Stream<GameEvent> events) {
    _sub?.cancel();
    _sub = events.listen(_handle);
  }

  void _handle(GameEvent event) {
    _decayTimer?.cancel();
    switch (event) {
      case GameEvent.validMove:
      case GameEvent.goodMove:
        _lightIntensity    = (_lightIntensity    + 0.08).clamp(0.3, 1.0);
        _particleIntensity = (_particleIntensity + 0.05).clamp(0.3, 1.0);
        notifyListeners();
        _scheduleDecay(1500);
        break;

      case GameEvent.comboStarted:
      case GameEvent.comboContinued:
        _lightIntensity    = (_lightIntensity    + 0.20).clamp(0.3, 1.0);
        _particleIntensity = (_particleIntensity + 0.20).clamp(0.3, 1.0);
        notifyListeners();
        _scheduleDecay(2000);
        break;

      case GameEvent.tubeCompleted:
        _lightIntensity    = (_lightIntensity + 0.35).clamp(0.3, 1.0);
        _particleIntensity = 0.85;
        _bloomActive       = true;
        notifyListeners();
        _scheduleDecay(2500);
        break;

      case GameEvent.levelCompleted:
        _lightIntensity    = 1.0;
        _particleIntensity = 1.0;
        _bloomActive       = true;
        notifyListeners();
        _scheduleDecay(5000);
        break;

      case GameEvent.gameOver:
        _lightIntensity    = 0.1;
        _particleIntensity = 0.1;
        _bloomActive       = false;
        notifyListeners();
        _scheduleDecay(4000);
        break;

      case GameEvent.playerIdle:
        _lightIntensity    = 0.3;
        _particleIntensity = 0.3;
        _bloomActive       = false;
        notifyListeners();
        break;

      default:
        break;
    }
  }

  void _scheduleDecay(int ms) {
    _decayTimer = Timer(Duration(milliseconds: ms), () {
      _lightIntensity    = (_lightIntensity    - 0.15).clamp(0.3, 1.0);
      _particleIntensity = (_particleIntensity - 0.15).clamp(0.3, 1.0);
      if (_bloomActive && _lightIntensity <= 0.45) _bloomActive = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _decayTimer?.cancel();
    super.dispose();
  }
}
