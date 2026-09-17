# Android production integration

The game runtime is native Godot 4. The only pieces that cannot be made genuinely live from a portable project archive are Google Play services that require the developer's Play Console account, signed application, store products and Android SDK/plugin dependencies.

## Google Play Billing

Create these in Play Console with the exact IDs:

- remove_ads_day
- remove_ads_weekend
- remove_ads_month
- hint_pack_small
- hint_pack_large
- coin_pack_starter
- mega_pack

Connect the native billing plugin to `scripts/services/monetization.gd` and call `deliver_verified_purchase()` only after the store reports a verified completed transaction. Do not grant products when the purchase button is merely pressed.

## AdMob

Connect a Godot Android AdMob plugin and configure the application's AdMob App ID plus banner/interstitial/rewarded/rewarded-interstitial/native unit IDs in the Android manifest/plugin configuration. Reward callbacks should call `deliver_verified_reward()` only from the plugin's earned-reward callback.

The original Flutter project contains the existing AdMob configuration; copy those values into the Android release configuration rather than hard-coding them into gameplay logic.

## Release requirements

1. Export a signed AAB from Godot.
2. Use the same package name: `com.chastechgroup.crystalcascade`.
3. Upload to Play Console internal testing first.
4. Test purchases with license testers.
5. Test rewarded ads, ad-removal entitlement, restore purchases and app relaunch persistence.
6. Verify Android back-button behavior, rotation lock, audio focus and lifecycle resume/pause.
