# Crystal Cascade 2.7.0 — full-body Cass, cameraman, retention, launch

Written without being able to run Godot (no engine in my sandbox). Art, sounds and
poses were checked in previews; code with a static linter and call-arity checks.
First thing on your phone: build the APK, launch, play one level.

## What changed
| Area | Change |
|---|---|
| Avatar | **Full body** Cass at the right edge of the game screen: legs, boots, tunic, cape, arms, hands, glowing orb, hair, face. Procedural poses: idle, happy, cheer, dance, clap, wave, point, think, surprised, sad, angry. Lip-flap while she talks, blinking, looks at the tube you tap, tint follows the selected crystal. Tap her upper body: she waves and giggles. |
| Avatar sounds | 11 voice lines (yay, wow, hmm, think, oh no, oops, nope, hello, cheer, giggle, sigh) + whoosh, chime, chest, streak, tube-drop, star. **Synthesised placeholders** (formant babble). Drop recorded files with the same names into `assets/sounds` to replace them. Settings: "Cass's Voice" toggle. |
| Camera | Camera button removed. Auto cameraman films the match: 6 shots (wide, 3/4 left, high, 3/4 right, low hero, crane) with slow drift, push-in on select, tracking on a move, whip + FOV punch on a match, reveal on a new tube, victory orbit, defeat pull-back, hand-held feel. **Manual:** drag on the table (auto pauses ~4 s, then resumes). Settings: "Auto Camera" toggle. |
| Tube layout | Up to 6 tubes in ONE row (nothing hides behind anything). 7-10 tubes: two staggered rows, back row on a raised tier of the table, so every tube stays visible and tappable. New tubes go at the end of the layout; existing tubes glide to their new spots and the new one drops in with a glow. Collision boxes are slimmer, and a drag never selects a tube. |
| Power-ups | HINT, +MOVES and +TUBE each open a choice: **use coins** or **watch a video (free)**. Coin price shown; "Not enough coins" / "Video not ready" handled. |
| Launch | New splash: studio line, animated logo, loading bar with status + tips. It preloads art and sound, builds the 3D world, starts ads/billing, and **warms up shaders** (first level starts without a hitch). Minimum 2.6 s, then fade to Home, Cass says hello, daily login popup. |
| Retention | Daily login streak (7 days, big reward on day 7, watch a video to double). Daily quests (3 per day, same on all devices). Star milestones (5, 15, 30, 60, 100, 200 stars). Win streak bonus. Combo bonus + banner. Treasure chest every 3rd win (video doubles it). Cass nudges you after 14 s idle ("Stuck? Tap HINT"). Rewards hub screen + gift button with red dot on Home. |
| Shop | **Banner removed.** Whole screen is one scroll list. New: Rewards shortcut, lives section (watch video / refill for coins), 3 hints for coins. |
| Scrolling | Root cause found: buttons and cards swallowed the touch, so drag-scroll only worked on empty space. Now every list (Shop, Rewards, Settings, Level Select, Result) scrolls from anywhere; a press is cancelled once you scroll, so nothing triggers by accident. |

## Money flow
Rewarded: shop coins/hints/lives, power-up dialogs, game over (+5 moves, +1 life), double coins, double login, double chest.
Interstitial: every 2nd finished level at Next/Replay (60 s cap). Banner: Level Select only.
IAP: unchanged (7 products).

## Before you publish (unchanged from 2.6.0)
Create the 7 in-app products; AdMob UMP (GDPR) message; set `PRIVACY_POLICY_URL`;
target SDK 36; Data safety form.

## Honest limitations
* Nothing was seen running. Camera distances, avatar framing, table/tier sizes and UI spacing are calculated: if anything is off-screen or the wrong size it is a one-number fix (send a screenshot).
* Voice lines are synthesised babble, not human recordings.
* The two-row tier layout (7+ tubes) only appears from about level 51; test it with a high level via Level Select after unlocking, or by buying extra tubes on a 6-tube level.
* Local push notifications (another retention tool) need a plugin; not included.

## Regenerate art / sounds
`python3 tools/generate_assets.py` (icons, buttons, textures) and `python3 tools/generate_sounds.py` (voice + effects). Needs numpy, Pillow, scipy (scipy optional).
