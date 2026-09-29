# Crystal Cascade — audit report (2026-09-29)

**Method.** I read every script, config, the CI workflow and the Flutter reference. I could NOT run Godot
(no engine, no network in my sandbox), so nothing here is verified by execution. It was checked by reading,
a custom static lint (balanced brackets, no duplicate funcs, no undefined helpers, cross-script call checks)
and API research for the plugins.

## About your log
The trail stops after `world.arrange returned — calling _connect_tubes()`. Between that line and the next
`_trail` there is one trivial statement, so a script bug cannot explain it. Either that run was an older
build (before the extra `_connect_tubes` trail lines), or the process died outside script code
(GPU driver, memory). I cannot prove which. So: every crash/hang candidate I found is removed, and new
trail lines tell us next time whether a death is in scripts, input, or rendering.

## Fixed — crash / stability
1. **Use-after-free on the first tap** (`main.gd` `_sync_visuals`, `world.gd` `arrange`): crystals/tubes were
   `free()`d synchronously from inside their own tap signal. Now `remove_child` + `queue_free`, and taps are
   handled with `call_deferred` (`_handle_tap`). Certain crash on first crystal tap.
2. **Up to ~85 OmniLight3D** (one per crystal, one per tube) in the GL Compatibility renderer. Removed;
   selection/highlight now uses emission on shared materials.
3. **Background particles were ~490k triangles/frame** (120 default 64x32 spheres). Now 60 particles,
   6x3 segments, unshaded.
4. **Directional shadows + glow** off by default (`KEY_LIGHT_SHADOWS`, `ENABLE_GLOW` in `world.gd`).
   Glass tubes also cast opaque shadows over the crystals inside them; shadows disabled on glass.
5. **Crystals rebuilt with new mesh+material every tap**; now shared per colour.
6. **Camera tween fight** (shake tween vs move tween on the same property) replaced by per-frame smoothing;
   shake uses camera h/v offset.

## Fixed — diagnostics (crash trail)
7. After tapping CONTINUE the clean-exit marker stayed at the top of the file, so every later crash was
   reported as clean. Now only the LAST line decides; paused-app counts as clean. Two file handles on the
   same file removed.
8. Added timestamps, device/GPU/memory header, `frame drawn after start_level` line (rendering-phase check),
   plugin diagnostics.
9. Crash screen text was inside a non-expanding container; now fills width.

## Fixed — gameplay / UX
10. Loss screen `+5 MOVES` button could never appear (`moves > 0` on a lost game).
11. Guardian: eyes/mouth floated in front of the head, was hidden behind the middle tube, and never
    stopped bouncing after a reaction.
12. Camera followed the tapped tube fully and panned the board out of the portrait frame (now 22%);
    camera pulls back for 3-row / tall boards.
13. Stale 3D board stayed visible behind menus/result screen.
14. Sound setting was ignored after restart; music never looped; SFX cut each other off.
15. Vibration setting did nothing (now wired, VIBRATE permission added).
16. Android back button quit the app mid-level; now pause/back/double-back-to-exit
    (`quit_on_go_back=false`).
17. Level-complete +5 coins missing vs Flutter reference.
18. Lives never refreshed in-session; failed purchase toast was overwritten by "Opening checkout";
    purchase completion yanked you to the shop; reset dialog used tiny stock fonts.
19. Save file now written atomically (temp + rename); numbers normalised to int after JSON load.

## Fixed — build
20. `reference/` (Flutter copy, duplicate images/audio) was imported and exported into the APK.
    Added `reference/.gdignore`. Unused `gem_*.png` excluded from export.
21. `audio/driver/enable_input` was in the `[rendering]` section (ignored); moved to `[audio]`.
22. Default clear colour set; `config/icon` set.
23. CI: non-blocking GDScript syntax check step added.

## Ads / billing — bridge fixed, NOT yet enabled
- `ClassDB.class_exists("Admob")` / `("BillingClient")` is always false: both plugins are GDScript
  `class_name` classes. Ads and billing could never start. Now detected via the global class list and the
  native singleton; nodes are added to the tree; reward type is remembered per request; UI reports
  "no ad available".
- Plugins are downloaded in CI but never ENABLED (`[editor_plugins]` missing), so their native code is not
  bundled. CI step added behind `ENABLE_MONETIZATION_PLUGINS` (default "false").
- The AdMob node's ad-unit-id property names are not in the docs I could reach. With the plugin enabled the
  trail prints them (`admob: node properties = ...`); paste that and the real IDs can be wired exactly.
  Until then the plugin uses Google TEST units (`ProductionConfig.USE_REAL_ADS = false`).

## Found, not changed (your decision)
- **Play target SDK**: presets say 35, your own checklist says 36, Play requires 36 for new apps/updates
  since Aug 31 2026. Change `gradle_build/target_sdk` and the SDK packages in the workflow after confirming
  Godot 4.6's template supports it.
- Adaptive launcher icon not set (Android 8+ shows the default Godot icon).
- Gameplay: a run of 4+ same-colour crystals clears all of them, which can strand 1-2 of that colour
  (unwinnable). Inherited from the Flutter version.
- Level generator does not guarantee solvability or check the move budget.
- Docs mention `android-production.yml` / other secret names; the workflow is `android.yml` with
  `KEYSTORE_BASE64` etc. Godot signs with one password, so `KEY_PASSWORD` must equal `KEYSTORE_PASSWORD`.
- `services/monetization.gd` is unused (duplicates `_deliver_product`).
