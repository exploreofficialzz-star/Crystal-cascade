# Crystal Cascade — Native Godot 4 3D Full Game

This project is a full native-Godot migration of the supplied Flutter Crystal Cascade game. The original Flutter project remains the reference for gameplay/economy behavior; Godot is now the game runtime and renderer.

## Full game systems

- Native Godot 4 3D runtime
- Endless procedural level curve matching the supplied Flutter constants
- Tube sorting rules and same-color/empty-tube validation
- 3+ matching and combo scoring
- Moves, score, stars, win/loss states
- Level unlocks and best progress
- Persistent coins, hints, lives and settings
- Life regeneration timing
- Daily 50-coin bonus
- Smart hints with hint/coin economy
- +5 moves rescue
- Extra-tube rescue up to 10 tubes
- Dynamic camera with four angles, focus movement and impact shake
- Real 3D glass tubes and procedural crystal geometry
- Animated crystal idle/selection/match behavior
- Living environment, fog, lighting and floating particles
- Human-like procedural 3D Guardian with gameplay reactions
- Tutorial overlay
- Home, level select, gameplay, pause, result, shop and settings flows
- Original game art and audio assets reused
- Portrait mobile configuration
- Android arm64 export preset
- Production-safe monetization abstraction

## What is intentionally not faked

Google Play Billing and AdMob require Android plugins/SDKs, the signed application identity and the developer's Play Console configuration. This project therefore contains a real integration boundary rather than pretending that a button press is a completed purchase or rewarded ad.

See `docs/ANDROID_PRODUCTION.md` for the final store integration steps.

## Run

Open the project folder in Godot 4.x and run `scenes/Main.tscn`.

## Android

Use the Android export preset. The package name is `com.chastechgroup.crystalcascade` and arm64 is enabled.
