class_name ProductionConfig
extends RefCounted

const APP_NAME := "Crystal Cascade"
const PACKAGE_NAME := "com.chastechgroup.crystalcascade"
const VERSION_NAME := "2.9.0"
const VERSION_CODE := 25
# Stamped by the CI build (run number). A new build forgets old crash strikes.
const BUILD_ID := "dev"

# true  = your LIVE AdMob ad units. This is what ships (APK and Play bundle).
# false = Google's public TEST ad units. Use it only while developing, or build
#         the APK with test ads through TEST_ADS_IN_APK in the CI workflow.
# While your own phone is not registered as a test device in AdMob, never tap
# live ads on it (Settings > Test devices in the AdMob console).
const USE_REAL_ADS := true

# Google's public TEST ad units. Used whenever USE_REAL_ADS is false.
const TEST_BANNER := "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
const TEST_REWARDED_INTERSTITIAL := "ca-app-pub-3940256099942544/5354046379"
const TEST_APP_OPEN := "ca-app-pub-3940256099942544/9257395921"

const ADMOB_APP_ID := "ca-app-pub-2492078126313994~1061290053"
const ADMOB_BANNER := "ca-app-pub-2492078126313994/2061480722"
const ADMOB_INTERSTITIAL := "ca-app-pub-2492078126313994/4548648504"
const ADMOB_REWARDED_INTERSTITIAL := "ca-app-pub-2492078126313994/8978848108"
const ADMOB_REWARDED := "ca-app-pub-2492078126313994/4998635250"
const ADMOB_NATIVE := "ca-app-pub-2492078126313994/7665766435"
# "App open" ad unit. Create it in AdMob, then either paste its id here or (better)
# set the repository variable ADMOB_APP_OPEN_ID in GitHub; the build fills this in.
# While it is empty there are simply no app-open ads in live mode.
const ADMOB_APP_OPEN := ""

# Store products live in scripts/services/monetization.gd (class Monetization).

# A live ad unit is only used if it is well formed AND belongs to the same
# AdMob publisher as ADMOB_APP_ID. A typo then gives "no ad" instead of a silent
# failure, and ids from another account can never slip in.
static func _live_unit(unit_id: String) -> String:
	var publisher: String = ADMOB_APP_ID.split("~")[0]
	var pattern := RegEx.new()
	pattern.compile("^ca-app-pub-[0-9]{16}/[0-9]{10}$")
	if pattern.search(unit_id) != null and unit_id.begins_with(publisher + "/"):
		return unit_id
	return ""

static func banner_id() -> String:
	if USE_REAL_ADS:
		return _live_unit(ADMOB_BANNER)
	return TEST_BANNER

static func interstitial_id() -> String:
	if USE_REAL_ADS:
		return _live_unit(ADMOB_INTERSTITIAL)
	return TEST_INTERSTITIAL

static func rewarded_id() -> String:
	if USE_REAL_ADS:
		return _live_unit(ADMOB_REWARDED)
	return TEST_REWARDED

static func rewarded_interstitial_id() -> String:
	if USE_REAL_ADS:
		return _live_unit(ADMOB_REWARDED_INTERSTITIAL)
	return TEST_REWARDED_INTERSTITIAL

static func app_open_id() -> String:
	if USE_REAL_ADS:
		return _live_unit(ADMOB_APP_OPEN)
	return TEST_APP_OPEN

# ── Monetisation tuning ──────────────────────────────────────────────────────
const REWARD_VIDEO_COINS := 30
const REWARD_VIDEO_HINTS := 1
const REWARD_EXTRA_MOVES := 5
const REWARD_CRYSTALS_PER_AD := 3

# Ad pacing. New players get a clean first few levels; after that a full-screen
# ad appears at most once per INTERSTITIAL_EVERY_LEVELS finished levels and
# never closer than INTERSTITIAL_MIN_SECONDS to the previous full-screen ad.
const INTERSTITIAL_MIN_LEVEL := 4
const INTERSTITIAL_EVERY_LEVELS := 2
const INTERSTITIAL_MIN_SECONDS := 75
const AFTER_REWARDED_QUIET_SECONDS := 120

# App-open ad: only after the player really left the app, mainly on the menus
# (the game screen only sometimes), never right after another full-screen ad.
const APP_OPEN_MIN_LEVEL := 3
const APP_OPEN_MIN_AWAY_SECONDS := 30
const APP_OPEN_MIN_GAP_SECONDS := 240
const APP_OPEN_MAX_PER_DAY := 6
const APP_OPEN_IN_GAME_CHANCE := 0.35
const APP_OPEN_QUIET_AFTER_AD_SECONDS := 6

# Rewarded-interstitial "bonus gift" offered on the level-complete screen.
const BONUS_GIFT_MIN_LEVEL := 3
const BONUS_GIFT_EVERY_WINS := 2
const BONUS_GIFT_COINS := 40
const BONUS_GIFT_HINTS := 1

# Shown in Settings only when not empty (Google Play requires a privacy policy).
const PRIVACY_POLICY_URL := ""
const PLAY_STORE_URL := "https://play.google.com/store/apps/details?id=com.chastechgroup.crystalcascade"
const SHARE_TEXT := "I'm playing Crystal Cascade, a 3D crystal puzzle. Try it: "

# Shown until Google Play returns the real localised prices.
const DEFAULT_PRICES := {
	"ads_free_monthly": "$0.99", "ads_free_annual": "$5.00",
	"hint_pack_small": "$0.45", "hint_pack_large": "$0.99",
	"coin_pack_starter": "$0.50", "mega_pack": "$0.99",
}

# List price of the annual plan before the 50% launch discount (display only).
const ANNUAL_LIST_PRICE := "$10.00"

const SUBSCRIPTIONS_URL := "https://play.google.com/store/account/subscriptions?package=com.chastechgroup.crystalcascade"
