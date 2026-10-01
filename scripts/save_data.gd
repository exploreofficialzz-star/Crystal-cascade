class_name SaveData
extends Node

const PATH := "user://crystal_cascade_save.json"
const MAX_LIVES := 5
const LIFE_REGEN_SECONDS := 30 * 60
const DAILY_BONUS := 50
const INT_KEYS := [
	"coins", "hints", "lives", "last_life_time", "total_stars",
	"highest_unlocked", "daily_bonus_time", "remove_ads_expiry",
]

var data: Dictionary = _default_data()

# Single source of truth for defaults (reset_all() used to keep its own copy).
static func _default_data() -> Dictionary:
	return {
		"coins": 25,
		"hints": 1,
		"lives": 5,
		"last_life_time": 0,
		"total_stars": 0,
		"highest_unlocked": 1,
		"tutorial": false,
		"sound": true,
		"music": true,
		"vibration": true,
		"daily_bonus_time": 0,
		"remove_ads_tier": "none",
		"remove_ads_expiry": 0,
		"levels": {},
		"processed_purchase_tokens": [],
	}

func _ready() -> void:
	load_data()
	_regen_lives()

func load_data() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("SaveData: save file unreadable, using defaults")
		return
	for key in _default_data().keys():
		if parsed.has(key):
			data[key] = parsed[key]
	# JSON has no int type, so numbers come back as floats.
	for key in INT_KEYS:
		data[key] = int(data[key])
	if not (data.levels is Dictionary):
		data.levels = {}
	if not (data.processed_purchase_tokens is Array):
		data.processed_purchase_tokens = []

# Atomic save: write a temp file, then rename over the real one. A crash or
# kill mid-write can no longer leave a half-written save (= lost progress and
# purchases).
func save() -> void:
	var tmp_path := PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveData: cannot write %s (error %d)" % [tmp_path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	var err := DirAccess.rename_absolute(tmp_path, PATH)
	if err != OK:
		DirAccess.remove_absolute(PATH)
		err = DirAccess.rename_absolute(tmp_path, PATH)
		if err != OK:
			push_warning("SaveData: rename failed (error %d)" % err)

func refresh_lives() -> void:
	_regen_lives()

func _regen_lives() -> void:
	var lives := int(data.lives)
	if lives >= MAX_LIVES:
		return
	var last := int(data.last_life_time)
	if last <= 0:
		return
	var now := int(Time.get_unix_time_from_system())
	var recovered := int((now - last) / LIFE_REGEN_SECONDS)
	if recovered > 0:
		data.lives = mini(MAX_LIVES, lives + recovered)
		if int(data.lives) >= MAX_LIVES:
			data.last_life_time = 0
		else:
			data.last_life_time = last + recovered * LIFE_REGEN_SECONDS
		save()

# Seconds until the next life is restored (0 when full).
func seconds_to_next_life() -> int:
	if int(data.lives) >= MAX_LIVES:
		return 0
	var last := int(data.last_life_time)
	if last <= 0:
		return 0
	var now := int(Time.get_unix_time_from_system())
	return maxi(0, LIFE_REGEN_SECONDS - (now - last))

func seconds_to_daily_bonus() -> int:
	var now := int(Time.get_unix_time_from_system())
	return maxi(0, 86400 - (now - int(data.daily_bonus_time)))

func ads_seconds_left() -> int:
	return maxi(0, int(data.remove_ads_expiry) - int(Time.get_unix_time_from_system()))

func level(id: int) -> Dictionary:
	return data.levels.get(str(id), {})

func set_level(id: int, stars: int, score: int) -> void:
	var old: Dictionary = level(id)
	var old_stars := int(old.get("stars", 0))
	var best_stars := maxi(old_stars, stars)
	data.levels[str(id)] = {"stars": best_stars, "score": maxi(int(old.get("score", 0)), score)}
	data.total_stars = int(data.total_stars) + maxi(0, best_stars - old_stars)
	if id + 1 > int(data.highest_unlocked):
		data.highest_unlocked = id + 1
	save()

func add_coins(amount: int) -> void:
	data.coins = maxi(0, int(data.coins) + amount)
	save()

func spend_coins(amount: int) -> bool:
	if int(data.coins) < amount:
		return false
	data.coins = int(data.coins) - amount
	save()
	return true

func add_hints(amount: int) -> void:
	data.hints = maxi(0, int(data.hints) + amount)
	save()

func use_hint() -> bool:
	if int(data.hints) <= 0:
		return false
	data.hints = int(data.hints) - 1
	save()
	return true

func use_life() -> bool:
	_regen_lives()
	if int(data.lives) <= 0:
		return false
	data.lives = int(data.lives) - 1
	if int(data.lives) < MAX_LIVES:
		data.last_life_time = int(Time.get_unix_time_from_system())
	save()
	return true

func add_life() -> void:
	_regen_lives()
	data.lives = mini(MAX_LIVES, int(data.lives) + 1)
	if int(data.lives) >= MAX_LIVES:
		data.last_life_time = 0
	save()

func can_claim_daily_bonus() -> bool:
	return int(Time.get_unix_time_from_system()) - int(data.daily_bonus_time) >= 86400

func claim_daily_bonus() -> bool:
	if not can_claim_daily_bonus():
		return false
	data.daily_bonus_time = int(Time.get_unix_time_from_system())
	data.coins = int(data.coins) + DAILY_BONUS
	save()
	return true

func set_setting(key: String, value: bool) -> void:
	data[key] = value
	save()

func ads_removed() -> bool:
	return int(data.remove_ads_expiry) > int(Time.get_unix_time_from_system())

func set_remove_ads(tier: String, seconds: int) -> void:
	data.remove_ads_tier = tier
	data.remove_ads_expiry = int(Time.get_unix_time_from_system()) + seconds
	save()

func has_processed_purchase(token: String) -> bool:
	if token == "":
		return false
	return token in data.get("processed_purchase_tokens", [])

func mark_processed_purchase(token: String) -> void:
	if token == "":
		return
	var tokens: Array = data.get("processed_purchase_tokens", [])
	if token not in tokens:
		tokens.append(token)
	# Keep a bounded idempotency ledger.
	if tokens.size() > 100:
		tokens = tokens.slice(tokens.size() - 100)
	data["processed_purchase_tokens"] = tokens
	save()

func reset_all() -> void:
	data = _default_data()
	save()
