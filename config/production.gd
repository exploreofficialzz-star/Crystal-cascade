class_name ProductionConfig
extends RefCounted

const APP_NAME := "Crystal Cascade"
const PACKAGE_NAME := "com.chastechgroup.crystalcascade"
const VERSION_NAME := "2.6.0"
const VERSION_CODE := 22

# false = Google's public TEST ad units (safe to tap while testing).
# CI flips this to true automatically for the Play Store bundle (AAB) only.
const USE_REAL_ADS := false

# Google's public TEST ad units. Used whenever USE_REAL_ADS is false.
const TEST_BANNER := "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
const TEST_REWARDED_INTERSTITIAL := "ca-app-pub-3940256099942544/5354046379"

const ADMOB_APP_ID := "ca-app-pub-2492078126313994~1061290053"
const ADMOB_BANNER := "ca-app-pub-2492078126313994/2061480722"
const ADMOB_INTERSTITIAL := "ca-app-pub-2492078126313994/4548648504"
const ADMOB_REWARDED_INTERSTITIAL := "ca-app-pub-2492078126313994/8978848108"
const ADMOB_REWARDED := "ca-app-pub-2492078126313994/4998635250"
const ADMOB_NATIVE := "ca-app-pub-2492078126313994/7665766435"

const PRODUCT_IDS := [
    "remove_ads_day", "remove_ads_weekend", "remove_ads_month",
    "hint_pack_small", "hint_pack_large", "coin_pack_starter", "mega_pack"
]

const CONSUMABLE_PRODUCT_IDS := [
    "remove_ads_day", "remove_ads_weekend", "remove_ads_month",
    "hint_pack_small", "hint_pack_large", "coin_pack_starter", "mega_pack"
]

static func banner_id() -> String:
	return ADMOB_BANNER if USE_REAL_ADS else TEST_BANNER

static func interstitial_id() -> String:
	return ADMOB_INTERSTITIAL if USE_REAL_ADS else TEST_INTERSTITIAL

static func rewarded_id() -> String:
	return ADMOB_REWARDED if USE_REAL_ADS else TEST_REWARDED

static func rewarded_interstitial_id() -> String:
	return ADMOB_REWARDED_INTERSTITIAL if USE_REAL_ADS else TEST_REWARDED_INTERSTITIAL

# ── Monetisation tuning ──────────────────────────────────────────────────────
const REWARD_VIDEO_COINS := 20
const REWARD_VIDEO_HINTS := 1
const REWARD_EXTRA_MOVES := 5
const INTERSTITIAL_EVERY_LEVELS := 2
const INTERSTITIAL_MIN_SECONDS := 60

# Shown in Settings only when not empty (Google Play requires a privacy policy).
const PRIVACY_POLICY_URL := ""
const PLAY_STORE_URL := "https://play.google.com/store/apps/details?id=com.chastechgroup.crystalcascade"
const SHARE_TEXT := "I'm playing Crystal Cascade, a 3D crystal puzzle. Try it: "

# Shown until Google Play returns the real localised prices.
const DEFAULT_PRICES := {
	"hint_pack_small": "$0.99", "hint_pack_large": "$1.99",
	"remove_ads_day": "$0.99", "remove_ads_weekend": "$2.99", "remove_ads_month": "$8.99",
	"coin_pack_starter": "$0.99", "mega_pack": "$4.99",
}
