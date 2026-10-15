class_name BootGuard
extends RefCounted

# A circuit breaker for crashes that scripts cannot catch (a native plugin, the
# GPU driver, an out-of-memory kill). Right before every risky step the game
# writes that step's name into a tiny file; when the step finishes it writes
# "run". A normal pause or exit clears the file. If the next launch still finds
# a step name in it, the game died inside that step: the step gets a strike and
# is left out (or lightened) until several clean launches in a row. One broken
# ad format, for example, switches only itself off; everything else keeps working.
# Nothing here is ever shown to the player.
#
# Step names used by the game:
#   warmup, ads_init, billing_init, notify_init, level_start,
#   load_<format>, show_<format>   (banner, interstitial, rewarded,
#                                   rewarded_interstitial, app_open)
#   boot, home, assets, world, core, run   (general: strike "lite")

const PATH := "user://boot_guard.json"
const CLEAN_RUNS_TO_FORGIVE := 4
const MAX_STRIKES := 6
const GENERAL_STEPS := ["boot", "home", "assets", "world", "core", "run"]

static var _data: Dictionary = {}
static var _crashed_step := ""

# First thing at start-up: finds out whether the last run died, and in which step.
static func begin() -> void:
	_data = _read()
	# A new build starts with a clean slate: whatever went wrong in an older build
	# (or the install itself closing the running game) must never keep a feature off.
	if str(_data.get("build", "")) != ProductionConfig.BUILD_ID:
		_data = {"op": "", "strikes": {}, "clean_runs": 0, "build": ProductionConfig.BUILD_ID}
	var last: String = str(_data.get("op", ""))
	_crashed_step = last
	if last != "":
		_strike(last)
		_data["clean_runs"] = 0
	_data["op"] = "boot"
	_write()

static func crashed_last_time() -> bool:
	return _crashed_step != ""

# Call right before a risky step.
static func mark(step: String) -> void:
	if str(_data.get("op", "")) == step:
		return
	_data["op"] = step
	_write()

# The risky step finished safely.
static func settle() -> void:
	mark("run")

# The app is going to the background or closing normally.
static func clean_exit() -> void:
	if str(_data.get("op", "")) == "":
		return
	_data["op"] = ""
	_write()

# The game booted and has been running for a while without dying.
static func stable() -> void:
	_data["op"] = "run"
	var runs: int = int(_data.get("clean_runs", 0)) + 1
	var needed: int = CLEAN_RUNS_TO_FORGIVE * maxi(1, _worst_strike())
	if runs >= needed:
		runs = 0
		_forgive_one()
	_data["clean_runs"] = runs
	_write()

static func strikes(feature: String) -> int:
	var table: Dictionary = _strike_table()
	return int(table.get(feature, 0))

# True when this step took the game down recently and should be left out. An ad
# format needs two strikes (leaving the app while an ad is open can look like a
# crash once); everything else is switched off after the first one.
static func blocked(step: String) -> bool:
	var needed := 1
	if step.begins_with("load_") or step.begins_with("show_"):
		needed = 2
	return strikes(step) >= needed

# ── internals ─────────────────────────────────────────────────────────────────

static func _strike(step: String) -> void:
	if GENERAL_STEPS.has(step):
		_add_strike("lite")
	elif step == "level_start":
		_add_strike("level_start")
		_add_strike("lite")
	else:
		_add_strike(step)

static func _strike_table() -> Dictionary:
	if not _data.has("strikes") or not (_data["strikes"] is Dictionary):
		_data["strikes"] = {}
	return _data["strikes"]

static func _add_strike(feature: String) -> void:
	var table: Dictionary = _strike_table()
	table[feature] = mini(MAX_STRIKES, int(table.get(feature, 0)) + 1)

static func _worst_strike() -> int:
	var table: Dictionary = _strike_table()
	var worst := 0
	for key in table.keys():
		worst = maxi(worst, int(table[key]))
	return worst

static func _forgive_one() -> void:
	var table: Dictionary = _strike_table()
	for key in table.keys():
		var left: int = int(table[key]) - 1
		if left <= 0:
			table.erase(key)
		else:
			table[key] = left

static func _read() -> Dictionary:
	var fresh: Dictionary = {"op": "", "strikes": {}, "clean_runs": 0}
	if not FileAccess.file_exists(PATH):
		return fresh
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return fresh
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed
	return fresh

static func _write() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_data))
	file.close()
