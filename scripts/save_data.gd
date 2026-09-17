class_name SaveData
extends Node

const PATH := "user://crystal_cascade_save.json"
const MAX_LIVES := 5
const LIFE_REGEN_SECONDS := 30 * 60
const DAILY_BONUS := 50

var data: Dictionary = {
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
    "processed_purchase_tokens": []
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
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        for key in data.keys():
            if parsed.has(key):
                data[key] = parsed[key]

func save() -> void:
    var file := FileAccess.open(PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))

func _regen_lives() -> void:
    var lives := int(data.lives)
    if lives >= MAX_LIVES:
        return
    var last := int(data.last_life_time)
    if last <= 0:
        return
    var now := Time.get_unix_time_from_system()
    var recovered := int((now - last) / LIFE_REGEN_SECONDS)
    if recovered > 0:
        data.lives = min(MAX_LIVES, lives + recovered)
        if int(data.lives) >= MAX_LIVES:
            data.last_life_time = 0
        else:
            data.last_life_time = last + recovered * LIFE_REGEN_SECONDS
        save()

func level(id: int) -> Dictionary:
    return data.levels.get(str(id), {})

func set_level(id: int, stars: int, score: int) -> void:
    var old: Dictionary = level(id)
    var old_stars := int(old.get("stars", 0))
    var best_stars := max(old_stars, stars)
    data.levels[str(id)] = {"stars": best_stars, "score": max(int(old.get("score", 0)), score)}
    data.total_stars = int(data.total_stars) + max(0, best_stars - old_stars)
    if id + 1 > int(data.highest_unlocked):
        data.highest_unlocked = id + 1
    save()

func add_coins(amount: int) -> void:
    data.coins = max(0, int(data.coins) + amount)
    save()

func spend_coins(amount: int) -> bool:
    if int(data.coins) < amount:
        return false
    data.coins -= amount
    save()
    return true

func add_hints(amount: int) -> void:
    data.hints = max(0, int(data.hints) + amount)
    save()

func use_hint() -> bool:
    if int(data.hints) <= 0:
        return false
    data.hints -= 1
    save()
    return true

func use_life() -> bool:
    _regen_lives()
    if int(data.lives) <= 0:
        return false
    data.lives -= 1
    if int(data.lives) < MAX_LIVES:
        data.last_life_time = int(Time.get_unix_time_from_system())
    save()
    return true

func add_life() -> void:
    _regen_lives()
    data.lives = min(MAX_LIVES, int(data.lives) + 1)
    if int(data.lives) >= MAX_LIVES:
        data.last_life_time = 0
    save()

func can_claim_daily_bonus() -> bool:
    return int(Time.get_unix_time_from_system()) - int(data.daily_bonus_time) >= 86400

func claim_daily_bonus() -> bool:
    if not can_claim_daily_bonus():
        return false
    data.daily_bonus_time = int(Time.get_unix_time_from_system())
    data.coins += DAILY_BONUS
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
    data = {
        "coins": 25, "hints": 1, "lives": 5, "last_life_time": 0,
        "total_stars": 0, "highest_unlocked": 1, "tutorial": false,
        "sound": true, "music": true, "vibration": true,
        "daily_bonus_time": 0, "remove_ads_tier": "none", "remove_ads_expiry": 0,
        "levels": {}, "processed_purchase_tokens": []
    }
    save()
