class_name Notifier
extends Node

# Local reminders that bring players back, through the Notification Scheduler
# plugin (godot-mobile-plugins/godot-notification-scheduler, v5). The plugin's
# classes are GDScript `class_name` classes, so they are looked up through the
# global class list and only used when the Android plugin is really bundled.
# Without the plugin every function here is a harmless no-op.
#
# What gets scheduled when the app goes to the background (and cancelled again
# when the player returns):
#   - lives are back / refilled
#   - the daily reward is ready
#   - the login streak is about to break (only for streaks of 2+ days)
#   - "we miss you" after 3 and 7 days away
# Nothing is ever sent between 21:00 and 09:00 local time.

const CHANNEL_ID := "crystal_reminders"
const ID_LIVES := 1001
const ID_DAILY := 1002
const ID_STREAK := 1003
const ID_AWAY_3 := 1004
const ID_AWAY_7 := 1005
const ALL_IDS := [ID_LIVES, ID_DAILY, ID_STREAK, ID_AWAY_3, ID_AWAY_7]
const QUIET_FROM_HOUR := 21
const QUIET_TO_HOUR := 9
const DAY := 86400

var save: SaveData
var scheduler: Node = null
var _ready_to_schedule := false
var _setup_started := false
var _want_permission := false

func setup(save_data: SaveData) -> void:
	# Only remembers the save here. The plugin itself starts later, the first
	# time it is really needed (see ensure_setup), never during launch.
	save = save_data

# True when the reminder plugin is part of this build. Starts nothing.
func is_available() -> bool:
	if OS.get_name() != "Android":
		return false
	return _class_path("NotificationScheduler") != "" and _has_singleton_like("notification")

# Starts the plugin on first use. Safe to call any number of times.
func ensure_setup() -> void:
	if _setup_started or not is_available() or BootGuard.blocked("notify_init"):
		return
	_setup_started = true
	var instance = _new_global("NotificationScheduler")
	if not (instance is Node):
		return
	scheduler = instance
	add_child(scheduler)
	if scheduler.has_signal("initialization_completed"):
		scheduler.connect("initialization_completed", _on_initialized)
	BootGuard.mark("notify_init")
	if scheduler.has_method("initialize"):
		scheduler.call("initialize")
	else:
		_on_initialized()

func _on_initialized(_a = null, _b = null) -> void:
	BootGuard.settle()
	_ready_to_schedule = true
	_create_channel()
	if _want_permission:
		_want_permission = false
		_ask_permission()

func _create_channel() -> void:
	if scheduler == null or not scheduler.has_method("create_notification_channel"):
		return
	var channel = _new_global("NotificationChannel")
	if channel == null:
		return
	_apply(channel, "set_id", CHANNEL_ID)
	_apply(channel, "set_name", "Game reminders")
	_apply(channel, "set_description", "Lives, daily rewards and streak reminders")
	_apply(channel, "set_importance", _importance_default())
	scheduler.call("create_notification_channel", channel)

func has_permission() -> bool:
	if scheduler == null:
		return false
	if scheduler.has_method("has_post_notifications_permission"):
		return bool(scheduler.call("has_post_notifications_permission"))
	return true

# Shows the system permission dialog (Android 13+) if it has not been granted.
func request_permission() -> void:
	if not is_available():
		return
	if scheduler == null or not _ready_to_schedule:
		_want_permission = true
		ensure_setup()
		return
	_ask_permission()

func _ask_permission() -> void:
	if scheduler != null and not has_permission() and scheduler.has_method("request_post_notifications_permission"):
		scheduler.call("request_post_notifications_permission")

func cancel_all() -> void:
	if scheduler == null or not scheduler.has_method("cancel"):
		return
	for id in ALL_IDS:
		scheduler.call("cancel", int(id))

# Called when the app goes to the background.
func schedule_all() -> void:
	if scheduler == null or save == null or not _ready_to_schedule:
		return
	if not bool(save.data.notifications) or not has_permission():
		return
	cancel_all()
	var now := int(Time.get_unix_time_from_system())

	# 1) lives
	save.refresh_lives()
	var lives := int(save.data.lives)
	if lives < SaveData.MAX_LIVES:
		var full_in := save.seconds_to_next_life() + (SaveData.MAX_LIVES - lives - 1) * SaveData.LIFE_REGEN_SECONDS
		if lives == 0:
			_push(ID_LIVES, "A life is back!", "Jump back in and clear the next table.", _quiet_safe(now + save.seconds_to_next_life()) - now)
		else:
			_push(ID_LIVES, "Lives refilled", "All %d lives are back. Ready to match some crystals?" % SaveData.MAX_LIVES, _quiet_safe(now + full_in) - now)

	# 2) daily reward (new day starts at UTC midnight; asked for at a civil hour)
	var daily_at := now + save.seconds_to_next_day()
	if save.login_available():
		daily_at = now + 5 * 3600
	_push(ID_DAILY, "Daily reward ready", "Your gift and a fresh set of quests are waiting.", _quiet_safe(daily_at) - now)

	# 3) streak about to break (the reward of the next day must be claimed that day)
	var streak := int(save.data.login_streak)
	if streak >= 2 and not save.login_available():
		var deadline := now + save.seconds_to_next_day() + DAY
		_push(ID_STREAK, "Keep your %d-day streak!" % streak, "Open the game today to keep it going and claim your reward.", _quiet_safe_before(deadline - 5 * 3600) - now)

	# 4) comeback nudges
	_push(ID_AWAY_3, "The crystals miss you", "Come back for a welcome-back gift.", _quiet_safe(now + 3 * DAY) - now)
	_push(ID_AWAY_7, "A big gift is waiting", "It has been a week. Claim your welcome-back gift and a fresh set of levels.", _quiet_safe(now + 7 * DAY) - now)

func _push(id: int, title: String, body: String, delay_s: int) -> void:
	var data = _new_global("NotificationData")
	if data == null:
		return
	_apply(data, "set_id", id)
	_apply(data, "set_channel_id", CHANNEL_ID)
	_apply(data, "set_title", title)
	_apply(data, "set_content", body)
	_apply(data, "set_delay", maxi(60, delay_s))
	if scheduler.has_method("schedule"):
		scheduler.call("schedule", data)

# ── quiet hours (local time) ──────────────────────────────────────────────────

func _local_offset() -> int:
	var tz: Dictionary = Time.get_time_zone_from_system()
	return int(tz.get("bias", 0)) * 60

# Moves a moment that falls in the night to 09:00 the same morning.
func _quiet_safe(unix_time: int) -> int:
	var local := unix_time + _local_offset()
	var sod := local % DAY
	var hour := sod / 3600
	if hour >= QUIET_FROM_HOUR:
		return unix_time + (DAY - sod) + QUIET_TO_HOUR * 3600
	if hour < QUIET_TO_HOUR:
		return unix_time + QUIET_TO_HOUR * 3600 - sod
	return unix_time

# Same, but for deadlines: a night-time moment moves back to the evening before.
func _quiet_safe_before(unix_time: int) -> int:
	var local := unix_time + _local_offset()
	var sod := local % DAY
	var hour := sod / 3600
	if hour >= QUIET_FROM_HOUR:
		return unix_time - (sod - (QUIET_FROM_HOUR - 1) * 3600)
	if hour < QUIET_TO_HOUR:
		return unix_time - sod - (DAY - (QUIET_FROM_HOUR - 1) * 3600)
	return unix_time

# ── plugin lookup helpers ─────────────────────────────────────────────────────

func _apply(obj: Object, method: String, value) -> void:
	if obj != null and obj.has_method(method):
		obj.call(method, value)

func _class_path(wanted: String) -> String:
	for entry in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == wanted:
			return str(entry.get("path", ""))
	return ""

func _new_global(wanted: String):
	var path := _class_path(wanted)
	if path == "":
		return null
	var script = load(path)
	if script == null:
		return null
	return script.new()

func _has_singleton_like(fragment: String) -> bool:
	for singleton_name in Engine.get_singleton_list():
		if str(singleton_name).to_lower().contains(fragment):
			return true
	return false

func _importance_default() -> int:
	var path := _class_path("NotificationChannel")
	if path != "":
		var script = load(path)
		if script != null:
			var consts: Dictionary = script.get_script_constant_map()
			if consts.has("Importance"):
				var enum_dict = consts["Importance"]
				if enum_dict is Dictionary and (enum_dict as Dictionary).has("DEFAULT"):
					return int((enum_dict as Dictionary)["DEFAULT"])
	return 3
