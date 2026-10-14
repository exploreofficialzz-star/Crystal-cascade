class_name SaveData
extends Node

const PATH := "user://crystal_cascade_save.json"
const MAX_LIVES := 5
const LIFE_REGEN_SECONDS := 30 * 60
const DAILY_BONUS := 25
const SUB_GRACE_SECONDS := 45 * 86400
const INT_KEYS := [
	"coins", "hints", "lives", "last_life_time", "total_stars",
	"highest_unlocked", "daily_bonus_time", "remove_ads_expiry",
	"login_streak", "login_last_claim", "quest_day", "win_streak",
	"wins_since_chest", "total_matches", "total_wins",
	"ads_sub_checked", "ao_day", "ao_count", "last_played_day", "comeback_day",
	"bonus_wins", "pick_day", "sessions", "first_day",
]
const CHEST_EVERY := 4

var data: Dictionary = _default_data()

# Single source of truth for defaults (reset_all() used to keep its own copy).
static func _default_data() -> Dictionary:
	return {
		"coins": 30,
		"hints": 3,
		"lives": 5,
		"last_life_time": 0,
		"total_stars": 0,
		"highest_unlocked": 1,
		"tutorial": false,
		"sound": true,
		"music": true,
		"vibration": true,
		"voice": true,
		"auto_camera": true,
		"login_streak": 0,
		"login_last_claim": -1,
		"quest_day": -1,
		"quest_progress": {},
		"quest_claimed": {},
		"milestones": [],
		"win_streak": 0,
		"wins_since_chest": 0,
		"total_matches": 0,
		"total_wins": 0,
		"daily_bonus_time": 0,
		"remove_ads_tier": "none",
		"remove_ads_expiry": 0,
		"ads_sub_active": false,
		"ads_sub_checked": 0,
		"ao_day": -1,
		"ao_count": 0,
		"notifications": true,
		"lite_mode": false,
		"notif_asked": false,
		"last_played_day": -1,
		"comeback_day": -1,
		"bonus_wins": 0,
		"pick_day": -1,
		"sessions": 0,
		"first_day": -1,
		"levels": {},
		"fails": {},
		"seen_twists": [],
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
	if not (data.fails is Dictionary):
		data.fails = {}
	if not (data.seen_twists is Array):
		data.seen_twists = []
	if not (data.processed_purchase_tokens is Array):
		data.processed_purchase_tokens = []
	if not (data.quest_progress is Dictionary):
		data.quest_progress = {}
	if not (data.quest_claimed is Dictionary):
		data.quest_claimed = {}
	var claimed: Array = []
	if data.milestones is Array:
		for m in data.milestones:
			claimed.append(int(m))
	data.milestones = claimed

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

# Seconds left on an old time-limited ad-free pass (subscriptions have no end date here).
func ads_seconds_left() -> int:
	return maxi(0, int(data.remove_ads_expiry) - int(Time.get_unix_time_from_system()))

# ── retention: daily login, quests, milestones, streaks, chest ───────────────

func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

func seconds_to_next_day() -> int:
	return 86400 - (int(Time.get_unix_time_from_system()) % 86400)

func login_available() -> bool:
	return int(data.login_last_claim) != today()

# Streak day (1..7) the player is on if they claim now.
func login_day_if_claimed() -> int:
	var t := today()
	var last := int(data.login_last_claim)
	var streak := int(data.login_streak)
	if last == t:
		return streak
	if last == t - 1:
		return (streak % 7) + 1
	return 1

# Returns the streak day that was claimed (0 if already claimed today).
func claim_login() -> int:
	if not login_available():
		return 0
	var day := login_day_if_claimed()
	data.login_streak = day
	data.login_last_claim = today()
	save()
	return day

func ensure_quests() -> void:
	var t := today()
	if int(data.quest_day) != t:
		data.quest_day = t
		data.quest_progress = {}
		data.quest_claimed = {}
		save()

func quest_add(id: String, amount: int) -> void:
	ensure_quests()
	var prog: Dictionary = data.quest_progress
	prog[id] = int(prog.get(id, 0)) + amount
	data.quest_progress = prog
	save()

func quest_progress_of(id: String) -> int:
	ensure_quests()
	return int(data.quest_progress.get(id, 0))

func quest_is_claimed(id: String) -> bool:
	ensure_quests()
	return bool(data.quest_claimed.get(id, false))

func quest_mark_claimed(id: String) -> void:
	var cl: Dictionary = data.quest_claimed
	cl[id] = true
	data.quest_claimed = cl
	save()

func milestone_is_claimed(stars: int) -> bool:
	return stars in data.milestones

func milestone_mark_claimed(stars: int) -> void:
	if not milestone_is_claimed(stars):
		data.milestones.append(stars)
		save()

func record_win() -> int:
	data.win_streak = int(data.win_streak) + 1
	data.wins_since_chest = int(data.wins_since_chest) + 1
	data.total_wins = int(data.total_wins) + 1
	save()
	return int(data.win_streak)

func record_loss() -> void:
	data.win_streak = 0
	save()

# Failed attempts in a row on one level (used to ease the next try a little).
func fail_count(id: int) -> int:
	return int(data.fails.get(str(id), 0))

func add_fail(id: int) -> void:
	var f: Dictionary = data.fails
	f[str(id)] = mini(9, int(f.get(str(id), 0)) + 1)
	data.fails = f
	save()

func clear_fail(id: int) -> void:
	var f: Dictionary = data.fails
	if f.has(str(id)):
		f.erase(str(id))
		data.fails = f
		save()

func twist_seen(t: String) -> bool:
	return t in data.seen_twists

func mark_twist_seen(t: String) -> void:
	if not twist_seen(t):
		data.seen_twists.append(t)
		save()

# Wins still needed for the next treasure chest.
func wins_to_chest() -> int:
	return maxi(0, CHEST_EVERY - int(data.wins_since_chest))

func chest_ready() -> bool:
	return int(data.wins_since_chest) >= CHEST_EVERY

func chest_opened() -> void:
	data.wins_since_chest = 0
	save()

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

# Ad-free while an old pass is running or while the Google Play subscription is
# active. The subscription flag is re-checked against Google Play on every launch.
func ads_removed() -> bool:
	var now := int(Time.get_unix_time_from_system())
	if int(data.remove_ads_expiry) > now:
		return true
	return bool(data.ads_sub_active) and now - int(data.ads_sub_checked) < SUB_GRACE_SECONDS

func ads_subscription_flag() -> bool:
	return bool(data.ads_sub_active)

func set_ads_subscription(active: bool) -> void:
	data.ads_sub_active = active
	data.ads_sub_checked = int(Time.get_unix_time_from_system()) if active else 0
	save()

func touch_ads_subscription() -> void:
	if bool(data.ads_sub_active):
		data.ads_sub_checked = int(Time.get_unix_time_from_system())
		save()

# App-open ad daily cap.
func app_open_allowed(max_per_day: int) -> bool:
	if int(data.ao_day) != today():
		return true
	return int(data.ao_count) < max_per_day

func app_open_shown() -> void:
	if int(data.ao_day) != today():
		data.ao_day = today()
		data.ao_count = 0
	data.ao_count = int(data.ao_count) + 1
	save()

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

# ── retention: sessions, comeback, bonus gift pacing ─────────────────────────

# Called once per app launch. Returns whole days since the player last played
# (0 on a same-day return, -1 on the very first launch).
func begin_session() -> int:
	var t := today()
	var away := -1
	if int(data.last_played_day) >= 0:
		away = maxi(0, t - int(data.last_played_day))
	if int(data.first_day) < 0:
		data.first_day = t
	data.sessions = int(data.sessions) + 1
	data.last_played_day = t
	save()
	return away

# Days since the first launch (0 = install day).
func days_since_install() -> int:
	if int(data.first_day) < 0:
		return 0
	return maxi(0, today() - int(data.first_day))

func comeback_available(away_days: int) -> bool:
	return away_days >= 2 and int(data.comeback_day) != today()

func comeback_claimed() -> void:
	data.comeback_day = today()
	save()

# Level-complete "bonus gift" (rewarded interstitial) is offered every few wins.
func bonus_gift_due(every: int) -> bool:
	return int(data.bonus_wins) >= every

func bonus_gift_note_win() -> void:
	data.bonus_wins = int(data.bonus_wins) + 1
	save()

func bonus_gift_reset() -> void:
	data.bonus_wins = 0
	save()

func pick_available() -> bool:
	return int(data.pick_day) != today()

func pick_claimed() -> void:
	data.pick_day = today()
	save()

func reset_all() -> void:
	data = _default_data()
	save()
