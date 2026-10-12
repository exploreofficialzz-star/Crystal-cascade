class_name Monetization
extends RefCounted

# Product catalogue: the single source of truth for what the store sells.
# The Play Console product ids must match these exactly.
#
#   Subscriptions (auto-renewing, one base plan each):
#     ads_free_monthly   $0.99 / month
#     ads_free_annual    $5.00 / year   (50% off the $10 list price)
#   One-time consumables:
#     hint_pack_small    100 hints                    $0.45
#     hint_pack_large    500 hints                    $0.99
#     coin_pack_starter  1,000 coins + 50 hints       $0.50
#     mega_pack          10,000 coins + 200 hints     $0.99

const ADS_MONTHLY := "ads_free_monthly"
const ADS_ANNUAL := "ads_free_annual"
const HINTS_SMALL := "hint_pack_small"
const HINTS_LARGE := "hint_pack_large"
const COINS_STARTER := "coin_pack_starter"
const COINS_MEGA := "mega_pack"

const SUBSCRIPTION_IDS := [ADS_MONTHLY, ADS_ANNUAL]

# Base-plan ids to create in Play Console (used if Google does not report them).
const DEFAULT_BASE_PLANS := {ADS_MONTHLY: "monthly", ADS_ANNUAL: "annual"}
const CONSUMABLE_IDS := [HINTS_SMALL, HINTS_LARGE, COINS_STARTER, COINS_MEGA]

# Time-limited ad-free passes that are no longer sold. A pass that was bought
# earlier and is still unclaimed on the Play account is still honoured.
const LEGACY_PASS_SECONDS := {
	"remove_ads_day": 24 * 60 * 60,
	"remove_ads_weekend": 48 * 60 * 60,
	"remove_ads_month": 30 * 24 * 60 * 60,
}

const GRANTS := {
	HINTS_SMALL: {"hints": 100},
	HINTS_LARGE: {"hints": 500},
	COINS_STARTER: {"coins": 1000, "hints": 50},
	COINS_MEGA: {"coins": 10000, "hints": 200},
}

static func all_ids() -> Array:
	var ids: Array = []
	ids.append_array(SUBSCRIPTION_IDS)
	ids.append_array(CONSUMABLE_IDS)
	return ids

static func is_subscription(product_id: String) -> bool:
	return SUBSCRIPTION_IDS.has(product_id)

static func is_consumable(product_id: String) -> bool:
	return CONSUMABLE_IDS.has(product_id) or LEGACY_PASS_SECONDS.has(product_id)

static func is_known(product_id: String) -> bool:
	return is_subscription(product_id) or is_consumable(product_id)

# Gives the player what a consumable pack contains. Subscriptions are not
# delivered here: their entitlement is read from Google Play on every launch.
static func deliver(save: SaveData, product_id: String) -> void:
	if save == null:
		return
	if LEGACY_PASS_SECONDS.has(product_id):
		save.set_remove_ads(product_id, int(LEGACY_PASS_SECONDS[product_id]))
		return
	if not GRANTS.has(product_id):
		return
	var grant: Dictionary = GRANTS[product_id]
	if grant.has("coins"):
		save.add_coins(int(grant["coins"]))
	if grant.has("hints"):
		save.add_hints(int(grant["hints"]))

# Short text for a pack's contents, e.g. "10,000 coins + 200 hints".
static func describe(product_id: String) -> String:
	if not GRANTS.has(product_id):
		return ""
	var grant: Dictionary = GRANTS[product_id]
	var parts: Array = []
	if grant.has("coins"):
		parts.append("%s coins" % group_digits(int(grant["coins"])))
	if grant.has("hints"):
		parts.append("%s hints" % group_digits(int(grant["hints"])))
	return " + ".join(parts)

static func group_digits(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
