class_name AndroidPlatform
extends Node

# Bridge to the AdMob and Google Play Billing Android plugins.
#
# IMPORTANT: both plugins expose their API as GDScript `class_name` classes
# (Admob, LoadAdRequest, BillingClient). ClassDB.class_exists() only knows
# NATIVE classes, so the old check always returned false and neither ads nor
# billing could ever start. This version:
#   1. looks the class up in the global script-class list,
#   2. requires the plugin's native Android singleton to actually be present
#      (i.e. the plugin was enabled at export time), and
#   3. adds the created node to the tree (BillingClient needs _ready()).
# If either plugin is missing everything degrades to a harmless no-op and the
# reason is written to the crash trail via the `diagnostic` signal.

signal rewarded_earned(reward_type: String)
signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, message: String)
signal ads_ready
signal diagnostic(message: String)

const AD_INTERSTITIAL_COOLDOWN := 30

var admob: Node = null
var billing_client: Node = null
var save: SaveData
var last_interstitial_time := 0
var rewarded_ads: Dictionary = {}
var interstitial_ad_id := ""
var rewarded_interstitial_ad_id := ""
var banner_ad_id := ""
var pending_purchase_id := ""
var pending_reward_type := "coins"
var initialized := false

func setup(save_data: SaveData) -> void:
    save = save_data
    if OS.get_name() != "Android":
        diagnostic.emit("platform: not Android, ads and billing disabled")
        return
    diagnostic.emit("platform: singletons = %s" % str(Engine.get_singleton_list()))
    _setup_admob()
    _setup_billing()

# ── helpers ───────────────────────────────────────────────────────────────────

func _global_class_path(wanted: String) -> String:
    for entry in ProjectSettings.get_global_class_list():
        if str(entry.get("class", "")) == wanted:
            return str(entry.get("path", ""))
    return ""

func _has_singleton_like(fragment: String) -> bool:
    for singleton_name in Engine.get_singleton_list():
        if str(singleton_name).to_lower().contains(fragment):
            return true
    return false

func _new_global(wanted: String):
    var path := _global_class_path(wanted)
    if path == "":
        return null
    var script = load(path)
    if script == null:
        return null
    return script.new()

func _connect_if_present(node: Object, signal_name: String, callable: Callable) -> void:
    if node != null and node.has_signal(signal_name):
        node.connect(signal_name, callable)

# ── AdMob ─────────────────────────────────────────────────────────────────────

func _setup_admob() -> void:
    if _global_class_path("Admob") == "":
        diagnostic.emit("admob: class 'Admob' not found (plugin files missing)")
        return
    if not _has_singleton_like("admob"):
        diagnostic.emit("admob: native singleton missing (plugin not enabled for export), ads off")
        return
    var instance = _new_global("Admob")
    if not (instance is Node):
        diagnostic.emit("admob: could not instantiate Admob node")
        return
    admob = instance
    add_child(admob)
    _connect_if_present(admob, "initialization_completed", _on_admob_initialized)
    _connect_if_present(admob, "banner_ad_loaded", _on_banner_loaded)
    _connect_if_present(admob, "interstitial_ad_loaded", _on_interstitial_loaded)
    _connect_if_present(admob, "rewarded_ad_loaded", _on_rewarded_loaded)
    _connect_if_present(admob, "rewarded_interstitial_ad_loaded", _on_rewarded_interstitial_loaded)
    _connect_if_present(admob, "rewarded_ad_user_earned_reward", _on_rewarded_earned)
    _connect_if_present(admob, "rewarded_interstitial_ad_user_earned_reward", _on_rewarded_interstitial_earned)
    _connect_if_present(admob, "interstitial_ad_dismissed_full_screen_content", _reload_interstitial)
    _connect_if_present(admob, "banner_ad_failed_to_load", _on_ad_failed.bind("banner"))
    _connect_if_present(admob, "interstitial_ad_failed_to_load", _on_ad_failed.bind("interstitial"))
    _connect_if_present(admob, "rewarded_ad_failed_to_load", _on_ad_failed.bind("rewarded"))
    _log_admob_properties()
    if ProductionConfig.USE_REAL_ADS:
        _apply_real_ad_ids()
    if admob.has_method("initialize"):
        admob.call("initialize")

# Lists the Admob node's script properties so the exact ad-unit-id property
# names show up in the trail (they are not documented in the plugin README).
func _log_admob_properties() -> void:
    var names: Array = []
    for p in admob.get_property_list():
        if int(p.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE:
            names.append(str(p.get("name", "")))
    diagnostic.emit("admob: node properties = %s" % str(names))

# Best-effort: only runs when ProductionConfig.USE_REAL_ADS is true. Matches
# string properties whose name contains "real" plus an ad kind. Check the trail
# to see what it matched.
func _apply_real_ad_ids() -> void:
    var ids := {
        "rewarded_interstitial": ProductionConfig.ADMOB_REWARDED_INTERSTITIAL,
        "rewarded": ProductionConfig.ADMOB_REWARDED,
        "interstitial": ProductionConfig.ADMOB_INTERSTITIAL,
        "banner": ProductionConfig.ADMOB_BANNER,
        "native": ProductionConfig.ADMOB_NATIVE,
    }
    if "is_real" in admob:
        admob.set("is_real", true)
    for p in admob.get_property_list():
        if not (int(p.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE):
            continue
        if int(p.get("type", 0)) != TYPE_STRING:
            continue
        var prop_name := str(p.get("name", ""))
        var lower := prop_name.to_lower()
        if not lower.contains("real") or lower.contains("ios") or lower.contains("app"):
            continue
        for kind in ["rewarded_interstitial", "rewarded", "interstitial", "banner", "native"]:
            if lower.contains(kind):
                admob.set(prop_name, ids[kind])
                diagnostic.emit("admob: set %s" % prop_name)
                break

func _on_admob_initialized(_status = null) -> void:
    initialized = true
    diagnostic.emit("admob: initialized")
    if save and save.ads_removed():
        return
    _load_banner()
    _load_interstitial()
    _load_rewarded()
    _load_rewarded_interstitial()
    ads_ready.emit()

func _on_ad_failed(_a = null, _b = null, kind := "") -> void:
    diagnostic.emit("admob: %s ad failed to load" % kind)

func _load_with(load_method: String) -> void:
    if admob == null or not admob.has_method(load_method):
        return
    var request = _new_global("LoadAdRequest")
    if request == null:
        diagnostic.emit("admob: LoadAdRequest class missing")
        return
    admob.call(load_method, request)

func _load_banner() -> void:
    _load_with("load_banner_ad")

func _load_interstitial() -> void:
    _load_with("load_interstitial_ad")

func _load_rewarded() -> void:
    _load_with("load_rewarded_ad")

func _load_rewarded_interstitial() -> void:
    _load_with("load_rewarded_interstitial_ad")

func _ad_id_of(info) -> String:
    if info != null and info.has_method("get_ad_id"):
        return str(info.call("get_ad_id"))
    return str(info) if info != null else ""

func _on_banner_loaded(info, _response = null) -> void:
    banner_ad_id = _ad_id_of(info)
    if banner_ad_id != "" and save and not save.ads_removed():
        admob.call("show_banner_ad", banner_ad_id)

func _on_interstitial_loaded(info, _response = null) -> void:
    interstitial_ad_id = _ad_id_of(info)

func _on_rewarded_loaded(info, _response = null) -> void:
    rewarded_ads["rewarded"] = _ad_id_of(info)

func _on_rewarded_interstitial_loaded(info, _response = null) -> void:
    rewarded_interstitial_ad_id = _ad_id_of(info)

# The reward type reported by AdMob is whatever is configured in the AdMob
# console, not "life"/"hint"/"coins", so the game remembers what it asked for.
func _on_rewarded_earned(_info = null, _reward_data = null) -> void:
    var granted := pending_reward_type
    pending_reward_type = "coins"
    rewarded_earned.emit(granted)
    _load_rewarded()

func _on_rewarded_interstitial_earned(_info = null, _reward_data = null) -> void:
    rewarded_earned.emit("coins")
    _load_rewarded_interstitial()

func _reload_interstitial(_info = null) -> void:
    interstitial_ad_id = ""
    _load_interstitial()

func show_interstitial() -> void:
    if admob == null or save == null or save.ads_removed():
        return
    var now := int(Time.get_unix_time_from_system())
    if now - last_interstitial_time < AD_INTERSTITIAL_COOLDOWN:
        return
    if interstitial_ad_id == "":
        return
    last_interstitial_time = now
    admob.call("show_interstitial_ad", interstitial_ad_id)
    interstitial_ad_id = ""

# Returns true if a rewarded ad was actually shown, so the UI can tell the
# player when none is available instead of promising a reward.
func show_rewarded(reward_type: String) -> bool:
    if admob == null:
        return false
    if not rewarded_ads.has("rewarded"):
        _load_rewarded()
        return false
    pending_reward_type = reward_type
    admob.call("show_rewarded_ad", rewarded_ads["rewarded"])
    rewarded_ads.erase("rewarded")
    return true

func show_rewarded_interstitial() -> void:
    if admob == null or rewarded_interstitial_ad_id == "":
        return
    admob.call("show_rewarded_interstitial_ad", rewarded_interstitial_ad_id)
    rewarded_interstitial_ad_id = ""

# ── Google Play Billing ───────────────────────────────────────────────────────

func _setup_billing() -> void:
    if _global_class_path("BillingClient") == "":
        diagnostic.emit("billing: class 'BillingClient' not found (plugin files missing)")
        return
    if not _has_singleton_like("billing"):
        diagnostic.emit("billing: native singleton missing (plugin not enabled for export), purchases off")
        return
    var instance = _new_global("BillingClient")
    if not (instance is Node):
        diagnostic.emit("billing: could not instantiate BillingClient")
        return
    billing_client = instance
    add_child(billing_client)
    _connect_if_present(billing_client, "connected", _on_billing_connected)
    _connect_if_present(billing_client, "connect_error", _on_billing_error)
    _connect_if_present(billing_client, "query_purchases_response", _on_query_purchases)
    _connect_if_present(billing_client, "on_purchase_updated", _on_purchase_updated)
    billing_client.call("start_connection")

func _on_billing_connected() -> void:
    diagnostic.emit("billing: connected")
    billing_client.call("query_product_details", PackedStringArray(ProductionConfig.PRODUCT_IDS), 0)
    billing_client.call("query_purchases", 0)

func _on_billing_error(code = 0, message = "") -> void:
    diagnostic.emit("billing: connect error %s %s" % [str(code), str(message)])
    purchase_failed.emit(pending_purchase_id, "%s: %s" % [str(code), str(message)])

# Returns true only if the Play checkout was really started.
func purchase(product_id: String) -> bool:
    if not ProductionConfig.PRODUCT_IDS.has(product_id):
        return false
    pending_purchase_id = product_id
    if billing_client == null:
        purchase_failed.emit(product_id, "Google Play Billing is not available")
        return false
    billing_client.call("purchase", product_id)
    return true

func restore_purchases() -> void:
    if billing_client:
        billing_client.call("query_purchases", 0)

func _on_query_purchases(response: Dictionary) -> void:
    if int(response.get("response_code", -1)) != 0:
        return
    for purchase_entry in response.get("purchases", []):
        _process_purchase(purchase_entry, false)

func _on_purchase_updated(response: Dictionary) -> void:
    if int(response.get("response_code", -1)) != 0:
        return
    for purchase_entry in response.get("purchases", []):
        _process_purchase(purchase_entry, true)

func _process_purchase(purchase_entry: Dictionary, consume_after: bool) -> void:
    # 1 == PURCHASED. Pending purchases must not be rewarded.
    if int(purchase_entry.get("purchase_state", 0)) != 1:
        return
    var ids = purchase_entry.get("product_ids", [])
    var token := str(purchase_entry.get("purchase_token", ""))
    for product_id in ids:
        if not ProductionConfig.PRODUCT_IDS.has(str(product_id)):
            continue
        if save and save.has_processed_purchase(token):
            if billing_client and token != "":
                billing_client.call("consume_purchase", token)
            continue
        if save:
            save.mark_processed_purchase(token)
            _deliver_product(str(product_id))
        purchase_completed.emit(str(product_id))
    if consume_after and billing_client and token != "":
        billing_client.call("consume_purchase", token)

func _deliver_product(product_id: String) -> void:
    match product_id:
        "hint_pack_small": save.add_hints(5)
        "hint_pack_large": save.add_hints(15)
        "coin_pack_starter":
            save.add_coins(500)
            save.add_hints(5)
        "mega_pack":
            save.add_coins(2000)
            save.add_hints(20)
            save.set_remove_ads("weekend", 48 * 60 * 60)
        "remove_ads_day": save.set_remove_ads("day", 24 * 60 * 60)
        "remove_ads_weekend": save.set_remove_ads("weekend", 48 * 60 * 60)
        "remove_ads_month": save.set_remove_ads("month", 30 * 24 * 60 * 60)
