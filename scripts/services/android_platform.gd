class_name AndroidPlatform
extends Node

# Bridge to the AdMob (godot-admob v6) and Google Play Billing (v3) plugins.
#
# Both plugins expose GDScript `class_name` classes, so ClassDB cannot see them.
# They are found through the global script-class list, and only used when the
# plugin's native Android singleton is really bundled in the build. If a plugin
# is missing everything degrades to a harmless no-op.
#
# Ads follow the documented flow:
#   consent (UMP) -> initialize() -> initialization_completed -> load_*()
#   requests come from admob.create_*_ad_request() and get our ad unit id.

signal rewarded_earned(reward_type: String)
signal rewarded_cancelled
signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, message: String)
signal restore_finished(count: int)
signal prices_updated
signal banner_height_changed(canvas_px: int)
signal diagnostic(message: String)

var admob: Node = null
var billing_client: Node = null
var save: SaveData
var initialized := false
var prices: Dictionary = {}

var _ads_started := false
var _consent_seen := false
var _interstitial_id := ""
var _rewarded_id := ""
var _banner_id := ""
var _banner_wanted := false
var _banner_loading := false
var _pending_reward := "coins"
var _reward_earned := false
var _after_interstitial: Callable = Callable()
var _levels_since_interstitial := 0
var _last_interstitial_ms := -1000000
var _pending_purchase := ""
var _restore_pending := false
var _restore_count := 0

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

func _has_prop(obj: Object, prop: String) -> bool:
	for p in obj.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false

func _connect_if_present(node: Object, signal_name: String, callable: Callable) -> void:
	if node != null and node.has_signal(signal_name):
		node.connect(signal_name, callable)

func _ad_id_of(info) -> String:
	if info != null and info is Object and (info as Object).has_method("get_ad_id"):
		return str((info as Object).call("get_ad_id"))
	return ""

func _remove_ads() -> bool:
	return save != null and save.ads_removed()

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
	if _has_prop(admob, "is_real"):
		admob.set("is_real", ProductionConfig.USE_REAL_ADS)
	add_child(admob)
	_connect_if_present(admob, "initialization_completed", _on_initialized)
	_connect_if_present(admob, "banner_ad_loaded", _on_banner_loaded)
	_connect_if_present(admob, "banner_ad_failed_to_load", _on_load_failed.bind("banner"))
	_connect_if_present(admob, "interstitial_ad_loaded", _on_interstitial_loaded)
	_connect_if_present(admob, "interstitial_ad_failed_to_load", _on_load_failed.bind("interstitial"))
	_connect_if_present(admob, "interstitial_ad_dismissed_full_screen_content", _on_interstitial_done)
	_connect_if_present(admob, "interstitial_ad_failed_to_show_full_screen_content", _on_interstitial_done)
	_connect_if_present(admob, "rewarded_ad_loaded", _on_rewarded_loaded)
	_connect_if_present(admob, "rewarded_ad_failed_to_load", _on_load_failed.bind("rewarded"))
	_connect_if_present(admob, "rewarded_ad_user_earned_reward", _on_rewarded_earned)
	_connect_if_present(admob, "rewarded_ad_dismissed_full_screen_content", _on_rewarded_dismissed)
	_connect_if_present(admob, "rewarded_ad_failed_to_show_full_screen_content", _on_rewarded_dismissed)
	_connect_if_present(admob, "consent_info_updated", _on_consent_info_updated)
	_connect_if_present(admob, "consent_info_update_failed", _on_consent_step_failed)
	_connect_if_present(admob, "consent_form_loaded", _on_consent_form_loaded)
	_connect_if_present(admob, "consent_form_failed_to_load", _on_consent_step_failed)
	_connect_if_present(admob, "consent_form_dismissed", _on_consent_step_failed)
	_start_consent()

# User Messaging Platform (GDPR / EEA). Any failure just continues to ads.
func _start_consent() -> void:
	if not (admob.has_method("update_consent_info") and admob.has_method("get_consent_status")):
		_init_ads()
		return
	var params = _new_global("ConsentRequestParameters")
	if params == null:
		_init_ads()
		return
	if _has_prop(params, "is_real"):
		params.set("is_real", ProductionConfig.USE_REAL_ADS)
	diagnostic.emit("consent: requesting update")
	admob.call("update_consent_info", params)
	# Never block ads forever if the consent callbacks never arrive.
	get_tree().create_timer(8.0).timeout.connect(_consent_timeout)

func _consent_timeout() -> void:
	if not _consent_seen:
		_init_ads()

func _consent_required_value() -> int:
	var path := _global_class_path("ConsentInformation")
	if path != "":
		var script = load(path)
		if script != null:
			var consts: Dictionary = script.get_script_constant_map()
			for key in consts.keys():
				var v = consts[key]
				if v is Dictionary:
					var enum_dict: Dictionary = v
					if enum_dict.has("REQUIRED"):
						return int(enum_dict["REQUIRED"])
				elif str(key) == "REQUIRED":
					return int(v)
	return 2

func _on_consent_info_updated() -> void:
	_consent_seen = true
	var status := int(admob.call("get_consent_status"))
	diagnostic.emit("consent: status %d" % status)
	if status == _consent_required_value():
		if admob.has_method("is_consent_form_available") and bool(admob.call("is_consent_form_available")):
			admob.call("show_consent_form")
		elif admob.has_method("load_consent_form"):
			admob.call("load_consent_form")
		else:
			_init_ads()
	else:
		_init_ads()

func _on_consent_form_loaded() -> void:
	if admob.has_method("show_consent_form"):
		admob.call("show_consent_form")
	else:
		_init_ads()

func _on_consent_step_failed(_error = null) -> void:
	_consent_seen = true
	_init_ads()

func _init_ads() -> void:
	if _ads_started or admob == null:
		return
	_ads_started = true
	if admob.has_method("initialize"):
		admob.call("initialize")

func _on_initialized(_status = null) -> void:
	initialized = true
	diagnostic.emit("admob: initialized (real ads: %s)" % str(ProductionConfig.USE_REAL_ADS))
	_load_interstitial()
	_load_rewarded()
	if _banner_wanted:
		_load_banner()

func _request(kind: String, unit_id: String):
	var method := "create_%s_ad_request" % kind
	if admob == null or not admob.has_method(method):
		return null
	var req = admob.call(method)
	if req != null and req is Object:
		var req_obj: Object = req
		if _has_prop(req_obj, "ad_unit_id"):
			req_obj.set("ad_unit_id", unit_id)
		if kind == "banner":
			_force_bottom(req_obj)
	return req

# Keep the banner at the bottom of the screen (our layouts reserve space there).
func _force_bottom(req: Object) -> void:
	if not _has_prop(req, "ad_position"):
		return
	var script = req.get_script()
	if script == null:
		return
	var consts: Dictionary = script.get_script_constant_map()
	for key in consts.keys():
		var v = consts[key]
		if v is Dictionary:
			var enum_dict: Dictionary = v
			if enum_dict.has("BOTTOM"):
				req.set("ad_position", enum_dict["BOTTOM"])
				return

func _load(kind: String, unit_id: String) -> void:
	if admob == null or not initialized:
		return
	var req = _request(kind, unit_id)
	var method := "load_%s_ad" % kind
	if req == null or not admob.has_method(method):
		diagnostic.emit("admob: cannot load %s" % kind)
		return
	admob.call(method, req)

func _load_banner() -> void:
	if _banner_loading or _remove_ads():
		return
	_banner_loading = true
	_load("banner", ProductionConfig.banner_id())

func _load_interstitial() -> void:
	_load("interstitial", ProductionConfig.interstitial_id())

func _load_rewarded() -> void:
	_load("rewarded", ProductionConfig.rewarded_id())

func _on_load_failed(_info = null, error = null, kind := "") -> void:
	var msg := ""
	if error != null and error is Object and _has_prop(error, "message"):
		msg = str((error as Object).get("message"))
	diagnostic.emit("admob: %s failed to load %s" % [kind, msg])
	if kind == "banner":
		_banner_loading = false

# ── banner ────────────────────────────────────────────────────────────────────

func show_banner() -> void:
	_banner_wanted = true
	if admob == null or _remove_ads():
		return
	if _banner_id != "":
		admob.call("show_banner_ad", _banner_id)
		_emit_banner_height()
	elif initialized:
		_load_banner()

func hide_banner() -> void:
	_banner_wanted = false
	if admob != null and _banner_id != "" and admob.has_method("hide_banner_ad"):
		admob.call("hide_banner_ad", _banner_id)
	banner_height_changed.emit(0)

func _on_banner_loaded(info, _response = null) -> void:
	_banner_loading = false
	_banner_id = _ad_id_of(info)
	if _banner_id == "":
		return
	if _banner_wanted and not _remove_ads():
		admob.call("show_banner_ad", _banner_id)
		_emit_banner_height()
	else:
		admob.call("hide_banner_ad", _banner_id)

func _emit_banner_height() -> void:
	var canvas_px := 170
	if admob != null and _banner_id != "" and admob.has_method("get_banner_dimension_in_pixels"):
		var dim = admob.call("get_banner_dimension_in_pixels", _banner_id)
		if dim is Vector2:
			var dv: Vector2 = dim
			var win_w := float(DisplayServer.window_get_size().x)
			if dv.y > 0.0 and win_w > 0.0:
				canvas_px = int(dv.y / win_w * 1080.0) + 8
	banner_height_changed.emit(canvas_px)

# Removes the banner for good (call after the player buys "remove ads").
func ads_removed_now() -> void:
	hide_banner()
	if admob != null and _banner_id != "" and admob.has_method("remove_banner_ad"):
		admob.call("remove_banner_ad", _banner_id)
		_banner_id = ""

# ── interstitial ──────────────────────────────────────────────────────────────

func level_finished() -> void:
	_levels_since_interstitial += 1

# Shows an interstitial if the pacing rules allow it. `on_done` runs when the ad
# closes (or right away by the caller when this returns false).
func try_interstitial(on_done: Callable) -> bool:
	if admob == null or not initialized or _remove_ads():
		return false
	if _interstitial_id == "":
		_load_interstitial()
		return false
	if _levels_since_interstitial < ProductionConfig.INTERSTITIAL_EVERY_LEVELS:
		return false
	if Time.get_ticks_msec() - _last_interstitial_ms < ProductionConfig.INTERSTITIAL_MIN_SECONDS * 1000:
		return false
	_after_interstitial = on_done
	_last_interstitial_ms = Time.get_ticks_msec()
	_levels_since_interstitial = 0
	var id := _interstitial_id
	_interstitial_id = ""
	admob.call("show_interstitial_ad", id)
	# If the plugin never reports the ad closing, do not leave the player stuck.
	get_tree().create_timer(30.0).timeout.connect(_interstitial_timeout)
	return true

func _interstitial_timeout() -> void:
	if _after_interstitial.is_valid():
		var cb := _after_interstitial
		_after_interstitial = Callable()
		cb.call()

func _on_interstitial_loaded(info, _response = null) -> void:
	_interstitial_id = _ad_id_of(info)

func _on_interstitial_done(_info = null, _error = null) -> void:
	_load_interstitial()
	var cb := _after_interstitial
	_after_interstitial = Callable()
	if cb.is_valid():
		cb.call()

# ── rewarded ──────────────────────────────────────────────────────────────────

func is_rewarded_ready() -> bool:
	return admob != null and initialized and _rewarded_id != ""

# Returns true if a rewarded ad was shown. The reward is granted from the
# rewarded_earned signal, tagged with what the player asked for.
func show_rewarded(reward_type: String) -> bool:
	if not is_rewarded_ready():
		_load_rewarded()
		return false
	_pending_reward = reward_type
	_reward_earned = false
	var id := _rewarded_id
	_rewarded_id = ""
	admob.call("show_rewarded_ad", id)
	return true

func _on_rewarded_loaded(info, _response = null) -> void:
	_rewarded_id = _ad_id_of(info)

func _on_rewarded_earned(_info = null, _reward_data = null) -> void:
	_reward_earned = true
	var granted := _pending_reward
	_pending_reward = "coins"
	rewarded_earned.emit(granted)

func _on_rewarded_dismissed(_info = null, _error = null) -> void:
	_load_rewarded()
	if not _reward_earned:
		rewarded_cancelled.emit()
	_reward_earned = false

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
	_connect_if_present(billing_client, "query_product_details_response", _on_product_details)
	_connect_if_present(billing_client, "query_purchases_response", _on_query_purchases)
	_connect_if_present(billing_client, "on_purchase_updated", _on_purchase_updated)
	billing_client.call("start_connection")

func _on_billing_connected() -> void:
	diagnostic.emit("billing: connected")
	billing_client.call("query_product_details", PackedStringArray(ProductionConfig.PRODUCT_IDS), 0)
	billing_client.call("query_purchases", 0)

func _on_billing_error(code = 0, message = "") -> void:
	diagnostic.emit("billing: connect error %s %s" % [str(code), str(message)])

func has_billing() -> bool:
	return billing_client != null

func get_price(product_id: String) -> String:
	if prices.has(product_id):
		return str(prices[product_id])
	return str(ProductionConfig.DEFAULT_PRICES.get(product_id, ""))

func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != 0:
		return
	for d in response.get("product_details", []):
		if d is Dictionary:
			var pid := str(d.get("product_id", ""))
			var price := ""
			var offer = d.get("one_time_purchase_offer_details", null)
			if offer is Dictionary:
				var offer_dict: Dictionary = offer
				price = str(offer_dict.get("formatted_price", ""))
			if price == "":
				price = str(d.get("formatted_price", ""))
			if pid != "" and price != "":
				prices[pid] = price
	prices_updated.emit()

# Returns true only if the Play checkout was really started.
func purchase(product_id: String) -> bool:
	if not ProductionConfig.PRODUCT_IDS.has(product_id):
		return false
	_pending_purchase = product_id
	if billing_client == null:
		purchase_failed.emit(product_id, "Purchases are not available on this build")
		return false
	billing_client.call("purchase", product_id)
	return true

func restore_purchases() -> void:
	if billing_client == null:
		restore_finished.emit(0)
		return
	_restore_pending = true
	_restore_count = 0
	billing_client.call("query_purchases", 0)

func _on_query_purchases(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) == 0:
		for entry in response.get("purchases", []):
			_process_purchase(entry, false)
	if _restore_pending:
		_restore_pending = false
		restore_finished.emit(_restore_count)

func _on_purchase_updated(response: Dictionary) -> void:
	var code := int(response.get("response_code", -1))
	if code != 0:
		var msg := "Purchase cancelled" if code == 1 else "Error %d %s" % [code, str(response.get("debug_message", ""))]
		purchase_failed.emit(_pending_purchase, msg)
		return
	for entry in response.get("purchases", []):
		_process_purchase(entry, true)

func _process_purchase(entry, consume_after: bool) -> void:
	if not (entry is Dictionary):
		return
	var purchase_entry: Dictionary = entry
	# 1 == PURCHASED. Pending purchases must not be rewarded.
	if int(purchase_entry.get("purchase_state", 0)) != 1:
		return
	var ids = purchase_entry.get("product_ids", [])
	var token := str(purchase_entry.get("purchase_token", ""))
	for product_id in ids:
		var pid := str(product_id)
		if not ProductionConfig.PRODUCT_IDS.has(pid):
			continue
		if save != null and save.has_processed_purchase(token):
			if billing_client != null and token != "":
				billing_client.call("consume_purchase", token)
			continue
		if save != null:
			save.mark_processed_purchase(token)
			_deliver_product(pid)
		_restore_count += 1
		purchase_completed.emit(pid)
	if consume_after and billing_client != null and token != "":
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
	if _remove_ads():
		ads_removed_now()
