# Crystal Cascade — Production Readiness

## Unified source
- [x] Original Flutter source preserved under `reference/flutter_original/`.
- [x] Original production AdMob IDs preserved and mapped into Godot.
- [x] Original Google Play product IDs preserved and mapped into Godot.
- [x] Godot is the production game runtime; Flutter is the historical/reference source. The two are not two competing runtimes in the Android release.

## Native game
- [x] Godot 4.6 project metadata
- [x] 3D board, tubes, crystals, camera, Guardian, reactions
- [x] Gameplay/economy/progression port
- [x] Persistence
- [x] Mobile touch flow

## Monetization
- [x] Real AdMob App ID and unit IDs mapped
- [x] AdMob file-based release configuration
- [x] AdMob export-discovery scene
- [x] Banner/interstitial/rewarded/rewarded-interstitial integration bridge
- [x] Reward granted only from earned-reward callback
- [x] 30-second fullscreen cooldown preserved
- [x] UMP consent hook included
- [x] Google Play Billing integration bridge
- [x] All seven original product IDs mapped
- [x] Purchase result handling
- [x] Consumable purchase consumption
- [x] Purchase-token idempotency ledger
- [x] Pending purchases are not rewarded

## Android release
- [x] Gradle Android export enabled
- [x] AAB/APK export presets
- [x] target SDK 36
- [x] min SDK 24
- [x] ARM64
- [x] package `com.chastechgroup.crystalcascade`
- [x] CI workflow for reproducible APK/AAB builds
- [x] Release keystore supplied through CI secrets, never committed

## Still account/device dependent
- [ ] Install the pinned AdMob v6.0 plugin and Billing 3.3.0 plugin in the local editor, or run the included GitHub Actions workflow which fetches them at build time.
- [ ] Add your release keystore to CI secrets / Godot export settings.
- [ ] Create/publish the seven Play Console products exactly as listed.
- [ ] Add the app to AdMob and verify the production ad units belong to this package/app.
- [ ] Run Play internal testing on a signed AAB.
- [ ] Test rewarded, purchases, restore/query behavior and lifecycle on a real Android device.
- [ ] Complete Play Console Data safety, content rating, ads declaration and store listing.

These cannot be verified from a source archive alone because they depend on the developer's Play Console/AdMob accounts and a real Android device.
