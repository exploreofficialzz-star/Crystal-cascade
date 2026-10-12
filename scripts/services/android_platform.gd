class_name AndroidPlatform
extends Node

# Bridge to the AdMob (godot-admob v6) and Google Play Billing (v3) plugins.
#
# Both plugins expose GDScript `class_name` classes, so ClassDB cannot see them.
# They are found through the global script-class list, and only used when the
# plugin's native Android singleton is really bundled in the build. If a plugin
# is missing everything degrades to a harmless no-op.
#
# Ad formats handled here:
#   banner               sticky at the bottom (Levels, Game, Level Complete / Game Over)
#   interstitial         paced between levels
#   rewarded             player-initiated (coins, hints, moves, crystals ...)
#   rewarded interstitial  opt-in "bonus gift" on the level-complete screen
#   app open             when the player comes back to the app (mostly on the menus)
#
# Ads follow the documented flow:
#   consent (UMP) -> initialize() -> initialization_completed -> load_*()

signal rewarded_earned(reward_type: String)
signal rewarded_cancelled
signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, message: String)
signal restore_finished(count: int)
signal prices_updated
signal banner_height_changed(canvas_px: int)
signal entitlement_changed
signal app_open_ready

const RETRY_MS := [5000, 15000, 30000, 60000]
const AD_MAX_AGE_MS := 55 * 60 * 1000
const APP_OPEN_MAX_AGE_MS := 3 * 60 * 60 * 1000

var admob: Node = null
var billing_client: Node = null
var save: SaveData
var initialized := false
var prices: Dictionary = {}
var sub_base_plans: Dictionary = {}

var _ads_started := false
var _consent_seen := false
var _interstitial_id := ""
var _rewarded_id := ""
var _bonus_id := ""
var _banner_id := ""
var _loaded_ms: Dictionary = {}
var _retry_count: Dictionary = {}
var _loading: Dictionary = {}
var _banner_wanted := false
var _banner_shown := false
var _app_open_loaded := false
var _pending_reward := "coins"
var _reward_earned := false
var _after_interstitial: Callable = Callable()
var _levels_since_interstitial := 0
var _last_interstitial_ms := -1000000
var _last_fullscreen_end_ms := -1000000
var _last_rewarded_end_ms := -1000000
var _last_app_open_ms := -1000000
var _fullscreen_open := false
var _purchase_flow_ms := -1000000

var _billing_ready := false
var _details_stage := 0
var _sync_stage := 0
var _sub_seen := false
var _pending_purchase := ""
var _restore_pending := false
var _restore_count := 0

func setup(save_data: SaveData) -> void:
	save = save_data
	if OS.get_name() != "Android":
		return
	_setup_admob()
	_setup_billing()

# Debug builds only; release builds stay silent.
func _dbg(msg: String) -> void:
	if OS.is_debug_build():
		print("[platform] " + msg)

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

func _method_arg_count(obj: Object, method: String) -> int:
	for m in obj.get_method_list():
		if str(m.get("name", "")) == method:
			var args = m.get("args", [])
			if args is Array:
				return (args as Array).size()
	return -1

func _connect_if_present(node: Object, signal_name: String, callable: Callable) -> void:
	if node != null and node.has_signal(signal_name):
		node.connect(signal_name, callable)

func _ad_id_of(info) -> String:
	if info != null and info is Object and (info as Object).has_method("get_ad_id"):
		return str((info as Object).call("get_ad_id"))
	return ""

func _remove_ads() -> bool:
	return save != null and save.ads_removed()

func is_ad_free() -> bool:
	return _remove_ads()

func _now() -> int:
	return Time.get_ticks_msec()

func _mark_loaded(kind: String) -> void:
	_loading[kind] = false
	_retry_count[kind] = 0
	_loaded_ms[kind] = _now()

func _fresh(kind: String, max_age_ms: int = AD_MAX_AGE_MS) -> bool:
	return _now() - int(_loaded_ms.get(kind, -max_age_ms)) < max_age_ms

# Looks up an enum value of one of the plugin classes (falls back to `fallback`).
func _enum_value(plugin_class: String, enum_name: String, key: String, fallback: int) -> int:
	var path := _global_class_path(plugin_class)
	if path != "":
		var script = load(path)
		if script != null:
			var consts: Dictionary = script.get_script_constant_map()
			if consts.has(enum_name):
				var enum_dict = consts[enum_name]
				if enum_dict is Dictionary and (enum_dict as Dictionary).has(key):
					return int((enum_dict as Dictionary)[key])
	return fallback

# ── AdMob ─────────────────────────────────────────────────────────────────────

func _setup_admob() -> void:
	if _global_class_path("Admob") == "":
		_dbg("admob: class 'Admob' not found (plugin files missing)")
		return
	if not _has_singleton_like("admob"):
		_dbg("admob: native singleton missing (plugin not enabled for export), ads off")
		return
	var instance = _new_global("Admob")
	if not (instance is Node):
		return
	admob = instance
	if _has_prop(admob, "is_real"):
		admob.set("is_real", ProductionConfig.USE_REAL_ADS)
	# We decide when the app-open ad may appear (screen, pacing, daily cap).
	if _has_prop(admob, "auto_show_on_resume"):
		admob.set("auto_show_on_resume", false)
	add_child(admob)
	_connect_if_present(admob, "initialization_completed", _on_initialized)
	_connect_if_present(admob, "banner_ad_loaded", _on_banner_loaded)
	_connect_if_present(admob, "banner_ad_failed_to_load", func(_i = null, e = null): _handle_load_failed("banner", e))
	_connect_if_present(admob, "interstitial_ad_loaded", _on_interstitial_loaded)
	_connect_if_present(admob, "interstitial_ad_failed_to_load", func(_i = null, e = null): _handle_load_failed("interstitial", e))
	_connect_if_present(admob, "interstitial_ad_showed_full_screen_content", _on_fullscreen_opened)
	_connect_if_present(admob, "interstitial_ad_dismissed_full_screen_content", _on_interstitial_done)
	_connect_if_present(admob, "interstitial_ad_failed_to_show_full_screen_content", _on_interstitial_done)
	_connect_if_present(admob, "rewarded_ad_loaded", _on_rewarded_loaded)
	_connect_if_present(admob, "rewarded_ad_failed_to_load", func(_i = null, e = null): _handle_load_failed("rewarded", e))
	_connect_if_present(admob, "rewarded_ad_showed_full_screen_content", _on_fullscreen_opened)
	_connect_if_present(admob, "rewarded_ad_user_earned_reward", _on_rewarded_earned)
	_connect_if_present(admob, "rewarded_ad_dismissed_full_screen_content", func(_i = null, _e = null): _handle_reward_closed("rewarded"))
	_connect_if_present(admob, "rewarded_ad_failed_to_show_full_screen_content", func(_i = null, _e = null): _handle_reward_closed("rewarded"))
	_connect_if_present(admob, "rewarded_interstitial_ad_loaded", _on_bonus_loaded)
	_connect_if_present(admob, "rewarded_interstitial_ad_failed_to_load", func(_i = null, e = null): _handle_load_failed("rewarded_interstitial", e))
	_connect_if_present(admob, "rewarded_interstitial_ad_showed_full_screen_content", _on_fullscreen_opened)
	_connect_if_present(admob, "rewarded_interstitial_ad_user_earned_reward", _on_rewarded_earned)
	_connect_if_present(admob, "rewarded_interstitial_ad_dismissed_full_screen_content", func(_i = null, _e = null): _handle_reward_closed("rewarded_interstitial"))
	_connect_if_present(admob, "rewarded_interstitial_ad_failed_to_show_full_screen_content", func(_i = null, _e = null): _handle_reward_closed("rewarded_interstitial"))
	_connect_if_present(admob, "app_open_ad_loaded", _on_app_open_loaded)
	_connect_if_present(admob, "app_open_ad_failed_to_load", func(_i = null, e = null): _handle_load_failed("app_open", e))
	_connect_if_present(admob, "app_open_ad_showed_full_screen_content", _on_fullscreen_opened)
	_connect_if_present(admob, "app_open_ad_dismissed_full_screen_content", _on_app_open_done)
	_connect_if_present(admob, "app_open_ad_failed_to_show_full_screen_content", _on_app_open_done)
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
	admob.call("update_consent_info", params)
	# Never block ads forever if the consent callbacks never arrive.
	get_tree().create_timer(8.0).timeout.connect(_consent_timeout)

func _consent_timeout() -> void:
	if not _consent_seen:
		_init_ads()

func _consent_required_value() -> int:
	return _enum_value("ConsentInformation", "ConsentStatus", "REQUIRED", _legacy_consent_required())

# Older plugin builds expose the enum under a different name; scan every enum.
func _legacy_consent_required() -> int:
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

func _on_consent_info_updated(_a = null) -> void:
	_consent_seen = true
	var status := int(admob.call("get_consent_status"))
	if status == _consent_required_value():
		if admob.has_method("is_consent_form_available") and bool(admob.call("is_consent_form_available")):
			admob.call("show_consent_form")
		elif admob.has_method("load_consent_form"):
			admob.call("load_consent_form")
		else:
			_init_ads()
	else:
		_init_ads()

func _on_consent_form_loaded(_a = null) -> void:
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
	_dbg("admob initialized (real ads: %s)" % str(ProductionConfig.USE_REAL_ADS))
	_load_rewarded()
	_load_bonus()
	if not _remove_ads():
		_load_interstitial()
		_load_app_open()
	if _banner_wanted:
		_load_banner()

func _request(kind: String, unit_id: String):
	var method := "create_%s_ad_request" % kind
	var req = null
	if admob != null and admob.has_method(method):
		req = admob.call(method)
	elif kind == "app_open":
		req = _new_global("LoadAdRequest")
	if req != null and req is Object:
		var req_obj: Object = req
		if _has_prop(req_obj, "ad_unit_id"):
			req_obj.set("ad_unit_id", unit_id)
		if kind == "banner":
			_configure_banner(req_obj)
	return req

# Bottom of the screen, inside the safe area (our layouts reserve space there).
func _configure_banner(req: Object) -> void:
	if _has_prop(req, "anchor_to_safe_area"):
		req.set("anchor_to_safe_area", true)
	if not _has_prop(req, "ad_position"):
		return
	var bottom = _bottom_position_value(_global_class_path("AdPosition"))
	if bottom == null and req.get_script() != null:
		bottom = _bottom_position_value("", req.get_script())
	if bottom != null:
		req.set("ad_position", bottom)

# Finds the BOTTOM member of the plugin's position enum (class AdPosition).
func _bottom_position_value(class_path: String, script_obj = null):
	var script = script_obj
	if script == null and class_path != "":
		script = load(class_path)
	if script == null:
		return null
	var consts: Dictionary = script.get_script_constant_map()
	for key in consts.keys():
		var v = consts[key]
		if v is Dictionary and (v as Dictionary).has("BOTTOM"):
			return (v as Dictionary)["BOTTOM"]
	return null

func _load(kind: String, unit_id: String) -> void:
	if admob == null or not initialized or unit_id == "":
		return
	if bool(_loading.get(kind, false)):
		return
	var req = _request(kind, unit_id)
	var method := "load_%s_ad" % kind
	if req == null or not admob.has_method(method):
		return
	_loading[kind] = true
	var arg_count := _method_arg_count(admob, method)
	if arg_count == 0:
		admob.call(method)
	elif kind == "app_open" and arg_count >= 2:
		admob.call(method, req, false)
	else:
		admob.call(method, req)

func _load_banner() -> void:
	if _remove_ads():
		return
	_load("banner", ProductionConfig.banner_id())

func _load_interstitial() -> void:
	if _remove_ads():
		return
	_load("interstitial", ProductionConfig.interstitial_id())

func _load_rewarded() -> void:
	_load("rewarded", ProductionConfig.rewarded_id())

func _load_bonus() -> void:
	_load("rewarded_interstitial", ProductionConfig.rewarded_interstitial_id())

func _load_app_open() -> void:
	if _remove_ads() or _app_open_loaded:
		return
	_load("app_open", ProductionConfig.app_open_id())

# Failed loads are retried with a growing delay so a bad connection never
# leaves a slot permanently empty and never hammers the ad server.
func _handle_load_failed(kind: String, error = null) -> void:
	_loading[kind] = false
	var msg := ""
	if error != null and error is Object and _has_prop(error, "message"):
		msg = str((error as Object).get("message"))
	_dbg("admob: %s failed to load %s" % [kind, msg])
	var n := int(_retry_count.get(kind, 0))
	_retry_count[kind] = n + 1
	var wait_ms: int = RETRY_MS[mini(n, RETRY_MS.size() - 1)]
	get_tree().create_timer(float(wait_ms) / 1000.0).timeout.connect(_reload.bind(kind))

func _reload(kind: String) -> void:
	match kind:
		"banner":
			if _banner_wanted and _banner_id == "":
				_load_banner()
		"interstitial":
			if _interstitial_id == "":
				_load_interstitial()
		"rewarded":
			if _rewarded_id == "":
				_load_rewarded()
		"rewarded_interstitial":
			if _bonus_id == "":
				_load_bonus()
		"app_open":
			_load_app_open()

func _on_fullscreen_opened(_a = null, _b = null) -> void:
	_fullscreen_open = true

func _full_screen_closed() -> void:
	_fullscreen_open = false
	_last_fullscreen_end_ms = _now()

# ── banner ────────────────────────────────────────────────────────────────────

# Idempotent: calling it again while the banner is up does nothing visible, so
# moving between Levels, Game and Level Complete never flickers or reloads it.
func show_banner() -> void:
	_banner_wanted = true
	if admob == null or _remove_ads():
		return
	if _banner_id != "":
		if not _banner_shown:
			admob.call("show_banner_ad", _banner_id)
			_banner_shown = true
		_emit_banner_height()
	elif initialized:
		_load_banner()

func hide_banner() -> void:
	_banner_wanted = false
	if admob != null and _banner_id != "" and _banner_shown and admob.has_method("hide_banner_ad"):
		admob.call("hide_banner_ad", _banner_id)
	_banner_shown = false
	banner_height_changed.emit(0)

func _on_banner_loaded(info, _response = null) -> void:
	_mark_loaded("banner")
	_banner_id = _ad_id_of(info)
	if _banner_id == "":
		return
	if _banner_wanted and not _remove_ads():
		admob.call("show_banner_ad", _banner_id)
		_banner_shown = true
		_emit_banner_height()
	else:
		admob.call("hide_banner_ad", _banner_id)
		_banner_shown = false

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

# Removes the banner for good while the player is ad-free.
func ads_removed_now() -> void:
	hide_banner()
	if admob != null and _banner_id != "" and admob.has_method("remove_banner_ad"):
		admob.call("remove_banner_ad", _banner_id)
		_banner_id = ""

# ── interstitial ──────────────────────────────────────────────────────────────

func level_finished() -> void:
	_levels_since_interstitial += 1

# Shows an interstitial if the pacing rules allow it. `on_done` runs when the ad
# closes (the caller continues by itself when this returns false).
func try_interstitial(on_done: Callable, level: int = 99) -> bool:
	if admob == null or not initialized or _remove_ads() or _fullscreen_open:
		return false
	if level < ProductionConfig.INTERSTITIAL_MIN_LEVEL:
		return false
	if _interstitial_id == "" or not _fresh("interstitial"):
		_interstitial_id = ""
		_load_interstitial()
		return false
	if _levels_since_interstitial < ProductionConfig.INTERSTITIAL_EVERY_LEVELS:
		return false
	var now := _now()
	if now - _last_interstitial_ms < ProductionConfig.INTERSTITIAL_MIN_SECONDS * 1000:
		return false
	if now - _last_fullscreen_end_ms < ProductionConfig.INTERSTITIAL_MIN_SECONDS * 1000:
		return false
	if now - _last_rewarded_end_ms < ProductionConfig.AFTER_REWARDED_QUIET_SECONDS * 1000:
		return false
	_after_interstitial = on_done
	_last_interstitial_ms = now
	_levels_since_interstitial = 0
	_fullscreen_open = true
	var id := _interstitial_id
	_interstitial_id = ""
	admob.call("show_interstitial_ad", id)
	# If the plugin never reports the ad closing, do not leave the player stuck.
	get_tree().create_timer(30.0).timeout.connect(_interstitial_timeout)
	return true

func _interstitial_timeout() -> void:
	if _after_interstitial.is_valid():
		_full_screen_closed()
		var cb := _after_interstitial
		_after_interstitial = Callable()
		cb.call()

func _on_interstitial_loaded(info, _response = null) -> void:
	_mark_loaded("interstitial")
	_interstitial_id = _ad_id_of(info)

func _on_interstitial_done(_info = null, _error = null) -> void:
	_full_screen_closed()
	_last_interstitial_ms = _now()
	_load_interstitial()
	var cb := _after_interstitial
	_after_interstitial = Callable()
	if cb.is_valid():
		cb.call()

# ── rewarded video ────────────────────────────────────────────────────────────

func is_rewarded_ready() -> bool:
	return admob != null and initialized and _rewarded_id != "" and _fresh("rewarded")

# Returns true if a rewarded ad was shown. The reward is granted from the
# rewarded_earned signal, tagged with what the player asked for.
func show_rewarded(reward_type: String) -> bool:
	if not is_rewarded_ready():
		_rewarded_id = ""
		_load_rewarded()
		return false
	_pending_reward = reward_type
	_reward_earned = false
	_fullscreen_open = true
	var id := _rewarded_id
	_rewarded_id = ""
	admob.call("show_rewarded_ad", id)
	return true

func _on_rewarded_loaded(info, _response = null) -> void:
	_mark_loaded("rewarded")
	_rewarded_id = _ad_id_of(info)

func _on_rewarded_earned(_info = null, _reward_data = null) -> void:
	_reward_earned = true
	var granted := _pending_reward
	_pending_reward = "coins"
	rewarded_earned.emit(granted)

func _handle_reward_closed(kind: String) -> void:
	_full_screen_closed()
	_last_rewarded_end_ms = _now()
	if kind == "rewarded_interstitial":
		_load_bonus()
	else:
		_load_rewarded()
	if not _reward_earned:
		rewarded_cancelled.emit()
	_reward_earned = false

# ── rewarded interstitial (opt-in bonus gift) ─────────────────────────────────

func is_bonus_ready() -> bool:
	return admob != null and initialized and _bonus_id != "" and _fresh("rewarded_interstitial")

# The caller must have asked the player first (the gift card on the level
# complete screen is the opt-in). Returns true if the ad was shown.
func show_bonus(reward_type: String) -> bool:
	if not is_bonus_ready():
		_bonus_id = ""
		_load_bonus()
		return false
	_pending_reward = reward_type
	_reward_earned = false
	_fullscreen_open = true
	var id := _bonus_id
	_bonus_id = ""
	admob.call("show_rewarded_interstitial_ad", id)
	return true

func _on_bonus_loaded(info, _response = null) -> void:
	_mark_loaded("rewarded_interstitial")
	_bonus_id = _ad_id_of(info)

# ── app open ──────────────────────────────────────────────────────────────────

func _on_app_open_loaded(_info = null, _response = null) -> void:
	_mark_loaded("app_open")
	_app_open_loaded = true
	app_open_ready.emit()

func _on_app_open_done(_info = null, _error = null) -> void:
	_full_screen_closed()
	_app_open_loaded = false
	_load_app_open()

func is_app_open_ready() -> bool:
	return admob != null and initialized and _app_open_loaded and _fresh("app_open", APP_OPEN_MAX_AGE_MS)

# Shows the app-open ad if every rule allows it. The caller decides whether the
# current screen is a good moment; the cadence rules live here.
func try_app_open() -> bool:
	if admob == null or not initialized or _remove_ads() or save == null:
		return false
	if not admob.has_method("show_app_open_ad") or _fullscreen_open:
		return false
	if int(save.data.highest_unlocked) < ProductionConfig.APP_OPEN_MIN_LEVEL:
		return false
	if not is_app_open_ready():
		_app_open_loaded = false
		_load_app_open()
		return false
	var now := _now()
	if now - _last_fullscreen_end_ms < ProductionConfig.APP_OPEN_QUIET_AFTER_AD_SECONDS * 1000:
		return false
	if now - _purchase_flow_ms < 12000:
		return false
	if now - _last_app_open_ms < ProductionConfig.APP_OPEN_MIN_GAP_SECONDS * 1000:
		return false
	if now - _last_interstitial_ms < ProductionConfig.INTERSTITIAL_MIN_SECONDS * 1000:
		return false
	if not save.app_open_allowed(ProductionConfig.APP_OPEN_MAX_PER_DAY):
		return false
	_last_app_open_ms = now
	save.app_open_shown()
	_fullscreen_open = true
	admob.call("show_app_open_ad")
	return true

# ── Google Play Billing ───────────────────────────────────────────────────────

func _setup_billing() -> void:
	if _global_class_path("BillingClient") == "":
		_dbg("billing: class 'BillingClient' not found (plugin files missing)")
		return
	if not _has_singleton_like("billing"):
		_dbg("billing: native singleton missing (plugin not enabled for export), purchases off")
		return
	var instance = _new_global("BillingClient")
	if not (instance is Node):
		return
	billing_client = instance
	add_child(billing_client)
	_connect_if_present(billing_client, "connected", _on_billing_connected)
	_connect_if_present(billing_client, "disconnected", _on_billing_disconnected)
	_connect_if_present(billing_client, "connect_error", _on_billing_error)
	_connect_if_present(billing_client, "query_product_details_response", _on_product_details)
	_connect_if_present(billing_client, "query_purchases_response", _on_query_purchases)
	_connect_if_present(billing_client, "on_purchase_updated", _on_purchase_updated)
	billing_client.call("start_connection")

func _product_type(key: String, fallback: int) -> int:
	return _enum_value("BillingClient", "ProductType", key, fallback)

func _on_billing_connected(_a = null) -> void:
	_billing_ready = true
	_details_stage = 1
	billing_client.call("query_product_details", PackedStringArray(Monetization.CONSUMABLE_IDS), _product_type("INAPP", 0))

func _on_billing_disconnected(_a = null) -> void:
	_billing_ready = false

func _on_billing_error(_code = 0, _message = "") -> void:
	_billing_ready = false
	if _restore_pending:
		_restore_pending = false
		restore_finished.emit(0)

func has_billing() -> bool:
	return billing_client != null

func get_price(product_id: String) -> String:
	if prices.has(product_id):
		return str(prices[product_id])
	return str(ProductionConfig.DEFAULT_PRICES.get(product_id, ""))

func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) == 0:
		for d in response.get("product_details", []):
			if d is Dictionary:
				_absorb_details(d)
		prices_updated.emit()
	# INAPP details first, then subscriptions, then the purchase sync.
	if _details_stage == 1:
		_details_stage = 2
		billing_client.call("query_product_details", PackedStringArray(Monetization.SUBSCRIPTION_IDS), _product_type("SUBS", 1))
	elif _details_stage == 2:
		_details_stage = 0
		refresh_entitlements()

func _absorb_details(d: Dictionary) -> void:
	var pid := str(d.get("product_id", ""))
	if pid == "":
		return
	var price := ""
	var offer = d.get("one_time_purchase_offer_details", null)
	if offer is Dictionary:
		price = str((offer as Dictionary).get("formatted_price", ""))
	var offers = d.get("subscription_offer_details", null)
	if offers is Array and (offers as Array).size() > 0:
		var chosen: Dictionary = {}
		for o in offers:
			if o is Dictionary and str((o as Dictionary).get("offer_id", "")) == "":
				chosen = o
				break
		if chosen.is_empty() and (offers as Array)[0] is Dictionary:
			chosen = (offers as Array)[0]
		var base_plan := str(chosen.get("base_plan_id", ""))
		if base_plan != "":
			sub_base_plans[pid] = base_plan
		var phases = chosen.get("pricing_phases", [])
		if phases is Array and (phases as Array).size() > 0:
			var last = (phases as Array)[(phases as Array).size() - 1]
			if last is Dictionary:
				price = str((last as Dictionary).get("formatted_price", price))
	if price == "":
		price = str(d.get("formatted_price", ""))
	if price != "":
		prices[pid] = price

# Returns true only if the Play checkout was really started.
func purchase(product_id: String) -> bool:
	if not Monetization.is_known(product_id) or Monetization.LEGACY_PASS_SECONDS.has(product_id):
		return false
	_pending_purchase = product_id
	if billing_client == null or not _billing_ready:
		purchase_failed.emit(product_id, "Store is not ready yet. Check your connection and try again.")
		return false
	_purchase_flow_ms = _now()
	if Monetization.is_subscription(product_id):
		var base_plan := str(sub_base_plans.get(product_id, Monetization.DEFAULT_BASE_PLANS.get(product_id, "")))
		if base_plan == "" or not billing_client.has_method("purchase_subscription"):
			purchase_failed.emit(product_id, "This plan is not available yet.")
			return false
		billing_client.call("purchase_subscription", product_id, base_plan)
	else:
		billing_client.call("purchase", product_id)
	return true

func restore_purchases() -> void:
	if billing_client == null:
		restore_finished.emit(0)
		return
	_restore_pending = true
	_restore_count = 0
	refresh_entitlements()

# Reads what the player owns from Google Play: unconsumed packs are delivered,
# and the ad-free subscription state is refreshed. Safe to call any time.
func refresh_entitlements() -> void:
	if billing_client == null or not _billing_ready or _sync_stage != 0:
		if _restore_pending and _sync_stage == 0:
			_restore_pending = false
			restore_finished.emit(_restore_count)
		return
	_sync_stage = 1
	_sub_seen = false
	billing_client.call("query_purchases", _product_type("INAPP", 0))

func _on_query_purchases(response: Dictionary) -> void:
	var ok := int(response.get("response_code", -1)) == 0
	if _sync_stage == 1:
		if ok:
			for entry in response.get("purchases", []):
				_process_purchase(entry, false)
		_sync_stage = 2
		billing_client.call("query_purchases", _product_type("SUBS", 1))
		return
	if _sync_stage == 2:
		_sync_stage = 0
		if ok:
			for entry in response.get("purchases", []):
				_process_purchase(entry, false)
			if _sub_seen:
				save.touch_ads_subscription()
			elif save.ads_subscription_flag():
				save.set_ads_subscription(false)
				entitlement_changed.emit()
		if _restore_pending:
			_restore_pending = false
			restore_finished.emit(_restore_count)
		return
	if ok:
		for entry in response.get("purchases", []):
			_process_purchase(entry, false)

func _on_purchase_updated(response: Dictionary) -> void:
	_purchase_flow_ms = _now()
	var code := int(response.get("response_code", -1))
	if code != 0:
		# 7 = already owned: pull it from the account instead of showing an error.
		if code == 7:
			refresh_entitlements()
			return
		var msg := "Purchase cancelled" if code == 1 else "Purchase failed (error %d)" % code
		purchase_failed.emit(_pending_purchase, msg)
		return
	for entry in response.get("purchases", []):
		_process_purchase(entry, true)

func _process_purchase(entry, from_checkout: bool) -> void:
	if not (entry is Dictionary) or save == null:
		return
	var purchase_entry: Dictionary = entry
	# 1 == PURCHASED. Pending purchases must not be rewarded yet.
	if int(purchase_entry.get("purchase_state", 0)) != 1:
		return
	var token := str(purchase_entry.get("purchase_token", ""))
	var acknowledged := bool(purchase_entry.get("is_acknowledged", false))
	for product_id in purchase_entry.get("product_ids", []):
		var pid := str(product_id)
		if not Monetization.is_known(pid):
			continue
		if Monetization.is_subscription(pid):
			_sub_seen = true
			_activate_subscription()
			if not acknowledged and token != "" and billing_client != null:
				billing_client.call("acknowledge_purchase", token)
			if from_checkout:
				purchase_completed.emit(pid)
			continue
		if save.has_processed_purchase(token):
			if billing_client != null and token != "":
				billing_client.call("consume_purchase", token)
			continue
		save.mark_processed_purchase(token)
		Monetization.deliver(save, pid)
		if _remove_ads():
			ads_removed_now()
		_restore_count += 1
		purchase_completed.emit(pid)
		if billing_client != null and token != "":
			billing_client.call("consume_purchase", token)

func _activate_subscription() -> void:
	var was := save.ads_removed()
	save.set_ads_subscription(true)
	if not was:
		ads_removed_now()
		entitlement_changed.emit()

func open_manage_subscription() -> void:
	OS.shell_open(ProductionConfig.SUBSCRIPTIONS_URL)
