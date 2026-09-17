class_name AndroidPlatform
extends Node

signal rewarded_earned(reward_type: String)
signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, message: String)
signal ads_ready

const AD_INTERSTITIAL_COOLDOWN := 30
var admob: Node
var billing_client: Object
var save: SaveData
var last_interstitial_time := 0
var rewarded_ads: Dictionary = {}
var interstitial_ad_id := ""
var rewarded_interstitial_ad_id := ""
var banner_ad_id := ""
var pending_purchase_id := ""
var initialized := false

func setup(save_data: SaveData) -> void:
    save = save_data
    _setup_admob()
    _setup_billing()

func _setup_admob() -> void:
    if not ClassDB.class_exists("Admob"):
        return
    var scene := load("res://scenes/AdmobConfig.tscn")
    if scene == null:
        return
    var instance = scene.instantiate()
    add_child(instance)
    admob = instance
    if admob.has_signal("initialization_completed"):
        admob.connect("initialization_completed", Callable(self, "_on_admob_initialized"))
    if admob.has_signal("banner_ad_loaded"):
        admob.connect("banner_ad_loaded", Callable(self, "_on_banner_loaded"))
    if admob.has_signal("interstitial_ad_loaded"):
        admob.connect("interstitial_ad_loaded", Callable(self, "_on_interstitial_loaded"))
    if admob.has_signal("rewarded_ad_loaded"):
        admob.connect("rewarded_ad_loaded", Callable(self, "_on_rewarded_loaded"))
    if admob.has_signal("rewarded_interstitial_ad_loaded"):
        admob.connect("rewarded_interstitial_ad_loaded", Callable(self, "_on_rewarded_interstitial_loaded"))
    if admob.has_signal("rewarded_ad_user_earned_reward"):
        admob.connect("rewarded_ad_user_earned_reward", Callable(self, "_on_rewarded_earned"))
    if admob.has_signal("rewarded_interstitial_ad_user_earned_reward"):
        admob.connect("rewarded_interstitial_ad_user_earned_reward", Callable(self, "_on_rewarded_interstitial_earned"))
    if admob.has_signal("interstitial_ad_dismissed_full_screen_content"):
        admob.connect("interstitial_ad_dismissed_full_screen_content", Callable(self, "_reload_interstitial"))
    admob.call("initialize")

func _on_admob_initialized(_status = null) -> void:
    initialized = true
    if save and save.ads_removed():
        return
    _load_banner()
    _load_interstitial()
    _load_rewarded()
    _load_rewarded_interstitial()
    if admob and admob.has_method("load_consent_form"):
        admob.call("load_consent_form")
    ads_ready.emit()

func _load_banner() -> void:
    if not admob: return
    var req = admob.call("create_banner_ad_request")
    if req:
        req.set("ad_unit_id", ProductionConfig.ADMOB_BANNER)
        req.set("anchor_to_safe_area", true)
        admob.call("load_banner_ad", req)

func _load_interstitial() -> void:
    if not admob: return
    var req = admob.call("create_interstitial_ad_request")
    if req:
        req.set("ad_unit_id", ProductionConfig.ADMOB_INTERSTITIAL)
        admob.call("load_interstitial_ad", req)

func _load_rewarded() -> void:
    if not admob: return
    var req = admob.call("create_rewarded_ad_request")
    if req:
        req.set("ad_unit_id", ProductionConfig.ADMOB_REWARDED)
        admob.call("load_rewarded_ad", req)

func _load_rewarded_interstitial() -> void:
    if not admob: return
    var req = admob.call("create_rewarded_interstitial_ad_request")
    if req:
        req.set("ad_unit_id", ProductionConfig.ADMOB_REWARDED_INTERSTITIAL)
        admob.call("load_rewarded_interstitial_ad", req)

func _on_banner_loaded(info, _response = null) -> void:
    banner_ad_id = info.get_ad_id()
    if not save.ads_removed():
        admob.call("show_banner_ad", banner_ad_id)

func _on_interstitial_loaded(info, _response = null) -> void:
    interstitial_ad_id = info.get_ad_id()

func _on_rewarded_loaded(info, _response = null) -> void:
    rewarded_ads["rewarded"] = info.get_ad_id()

func _on_rewarded_interstitial_loaded(info, _response = null) -> void:
    rewarded_interstitial_ad_id = info.get_ad_id()

func _on_rewarded_earned(_info, reward_data) -> void:
    var reward_type := "bonus"
    if reward_data is Object and reward_data.get("type"):
        reward_type = str(reward_data.get("type"))
    rewarded_earned.emit(reward_type)
    _load_rewarded()

func _on_rewarded_interstitial_earned(_info, _reward_data) -> void:
    rewarded_earned.emit("bonus")
    _load_rewarded_interstitial()

func _reload_interstitial(_info = null) -> void:
    interstitial_ad_id = ""
    _load_interstitial()

func show_interstitial() -> void:
    if not admob or save.ads_removed(): return
    var now := int(Time.get_unix_time_from_system())
    if now - last_interstitial_time < AD_INTERSTITIAL_COOLDOWN: return
    if interstitial_ad_id == "": return
    last_interstitial_time = now
    admob.call("show_interstitial_ad", interstitial_ad_id)
    interstitial_ad_id = ""

func show_rewarded(reward_type: String) -> void:
    if not admob: return
    if rewarded_ads.has("rewarded"):
        admob.call("show_rewarded_ad", rewarded_ads["rewarded"])
        rewarded_ads.erase("rewarded")
    else:
        _load_rewarded()

func show_rewarded_interstitial() -> void:
    if not admob or rewarded_interstitial_ad_id == "": return
    admob.call("show_rewarded_interstitial_ad", rewarded_interstitial_ad_id)
    rewarded_interstitial_ad_id = ""

func _setup_billing() -> void:
    if not ClassDB.class_exists("BillingClient"):
        return
    billing_client = ClassDB.instantiate("BillingClient")
    if billing_client == null: return
    if billing_client.has_signal("connected"):
        billing_client.connect("connected", Callable(self, "_on_billing_connected"))
    if billing_client.has_signal("connect_error"):
        billing_client.connect("connect_error", Callable(self, "_on_billing_error"))
    if billing_client.has_signal("on_purchase_updated"):
        billing_client.connect("on_purchase_updated", Callable(self, "_on_purchase_updated"))
    if billing_client.has_signal("query_purchases_response"):
        billing_client.connect("query_purchases_response", Callable(self, "_on_query_purchases"))
    billing_client.call("start_connection")

func _on_billing_connected() -> void:
    billing_client.call("query_product_details", PackedStringArray(ProductionConfig.PRODUCT_IDS), 0)
    billing_client.call("query_purchases", 0)

func _on_billing_error(code: int, message: String) -> void:
    purchase_failed.emit(pending_purchase_id, "%s: %s" % [code, message])

func purchase(product_id: String) -> void:
    if not ProductionConfig.PRODUCT_IDS.has(product_id):
        return
    pending_purchase_id = product_id
    if billing_client == null:
        purchase_failed.emit(product_id, "Google Play Billing is not available")
        return
    billing_client.call("purchase", product_id)

func restore_purchases() -> void:
    if billing_client:
        billing_client.call("query_purchases", 0)

func _on_query_purchases(response: Dictionary) -> void:
    if int(response.get("response_code", -1)) != 0: return
    for purchase in response.get("purchases", []):
        _process_purchase(purchase, false)

func _on_purchase_updated(response: Dictionary) -> void:
    if int(response.get("response_code", -1)) != 0: return
    for purchase in response.get("purchases", []):
        _process_purchase(purchase, true)

func _process_purchase(purchase: Dictionary, consume_after: bool) -> void:
    if int(purchase.get("purchase_state", 0)) != 1:
        return
    var ids: PackedStringArray = purchase.get("product_ids", PackedStringArray())
    var token := str(purchase.get("purchase_token", ""))
    for product_id in ids:
        if not ProductionConfig.PRODUCT_IDS.has(product_id):
            continue
        if save and save.has_processed_purchase(token):
            if billing_client and token != "": billing_client.call("consume_purchase", token)
            continue
        # Client-side store verification is delegated to Google Play's signed purchase
        # callback. Server-side verification can be added without changing gameplay.
        if save:
            save.mark_processed_purchase(token)
            _deliver_product(product_id)
        purchase_completed.emit(product_id)
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
