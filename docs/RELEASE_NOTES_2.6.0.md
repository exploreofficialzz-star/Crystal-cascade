# Crystal Cascade 2.6.0 — production UI, 3D table, avatar, ads

Everything below was written without being able to run Godot (no engine in my
sandbox). Assets were checked visually; code with a static linter and call-arity
checks. First thing to do on your phone: build the APK and play one level.

## What you get
| Area | Change |
|---|---|
| Screens | Home, Level Select, Shop, Settings, Level Complete / Game Over rebuilt to match your Flutter screenshots (gradient PLAY / LEVELS / SHOP pills, coin + lives chips, wizard-lab level grid, shop sections, toggles). All code-built, no scenes. |
| 3D | Wooden workbench with velvet cloth, gold trim, glowing rune pads under every tube, candles, books, potions, turned legs; rune rug; curved lab backdrop. Auto-sizes for 3 to 10 tubes. |
| Avatar | "Cass the Crystal Keeper": human character (hair, eyes with pupils/highlights, eyebrows, nose, blush, mouth, neck, cloak, scarf, arms, glowing orb, forehead crystal). Circular portrait at the TOP-RIGHT of the game screen. Reacts (happy, surprised, think, sad, angry), blinks, looks at the tube you tap, tints with the selected crystal's colour, and talks in a speech bubble. |
| Camera | Cinematic fly-in on level start, idle sway, smooth focus, FOV punch + shake on matches, victory orbit, defeat pull-back, 4 presets (CAMERA button), drag on the table to orbit (springs back). Auto-fits any phone aspect ratio. |
| Ads | Consent (UMP) -> init -> interstitial + rewarded preload; banner on Shop and Level Select; rewarded videos for coins, hints, lives, +5 moves and double coins; interstitial every 2nd level with a 60 s cap, shown on Next/Replay. |
| Purchases | Play Billing with localised prices, restore purchases, idempotent delivery, remove-ads handling. |
| Release | Adaptive launcher icon, version 2.6.0 (code 22), CI builds APK with TEST ads and AAB with REAL ads. |

## Money flow (where revenue comes from)
1. Rewarded: Shop "Watch Video" (+20 coins, +1 hint), Game Over (+5 moves, +1 life), Level Complete (double coins).
2. Interstitial: after every 2nd finished level, at the Next/Replay tap.
3. Banner: Shop and Level Select.
4. IAP: hint packs, coin packs, mega pack, remove-ads passes.
Tune numbers in `config/production.gd` (REWARD_*, INTERSTITIAL_*).

## Ads safety
* APK (for your phone) uses Google TEST ad units. Tap them freely.
* AAB (for Google Play) is switched to your REAL units automatically by CI.
  Never tap real ads on your own device.
* Plugins are now enabled in CI (`ENABLE_MONETIZATION_PLUGINS: "true"`).

## Before you publish (checklist)
- [ ] Play Console: create the 7 in-app products (ids in `config/production.gd`), upload the AAB to Internal testing and test a purchase with a licence tester.
- [ ] AdMob console: Privacy & messaging -> create the GDPR (UMP) message for EEA/UK, otherwise EU users will not get ads.
- [ ] Put your privacy policy URL in `PRIVACY_POLICY_URL` (the Settings row appears automatically). Google Play requires one.
- [ ] Target SDK: presets say 35, Play now requires 36 for new apps/updates. Change `gradle_build/target_sdk` and the SDK packages in the workflow, then confirm the Godot 4.6 template builds.
- [ ] Play Console: Data safety form must declare ads (AdMob) and purchases.
- [ ] Optional: native share sheet (needs the godot-share plugin; Share currently copies an invite link).

## Hidden diagnostics
Settings -> tap "Version" 7 times opens the crash-trail viewer with a COPY LOG
button. Set `SHOW_CRASH_TRAIL := true` in `scripts/main.gd` to show it
automatically after a crash.

## Known limitations
* 3D look (table, avatar framing, camera distances) is calculated, not seen. If something is off-screen or too big/small, send a screenshot and it is a one-number fix (`camera_director.gd` PRESETS / `avatar_portrait.gd` camera, `table_3d.gd` sizes).
* AdMob ad-unit overrides rely on `LoadAdRequest.ad_unit_id` and the `create_*_ad_request()` helpers from the plugin docs.
* Gameplay rules are unchanged (same level generator, same match rule).

## Regenerating art
`python3 tools/generate_assets.py` rebuilds all icons, gradient buttons and 3D
textures (needs Pillow + numpy). Outputs live in `assets/icons`, `assets/ui`, `assets/textures`.
