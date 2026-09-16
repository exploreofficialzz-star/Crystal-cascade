/// Gameplay events that drive the 2.5D Living Reaction system.
/// Fired by [GameProvider] and consumed by [CharacterReactionManager]
/// and [EnvironmentReactionManager].
enum GameEvent {
  playerSelectedGem,
  validMove,
  invalidMove,
  goodMove,
  badMove,
  comboStarted,
  comboContinued,
  tubeCompleted,
  levelNearCompletion,
  levelCompleted,
  gameOver,
  playerIdle,
}
