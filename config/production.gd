class_name ProductionConfig
extends RefCounted

const APP_NAME := "Crystal Cascade"
const PACKAGE_NAME := "com.chastechgroup.crystalcascade"
const VERSION_NAME := "2.5.0"
const VERSION_CODE := 21

# false = the AdMob plugin uses its built-in TEST ad units (safe while testing).
# Set true only for the release build you ship, never while tapping ads yourself.
const USE_REAL_ADS := false

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
