class_name Rewards
extends RefCounted

# Static content for the retention systems (daily login streak, daily quests,
# star milestones) and the helpers that grant a reward.

const LOGIN := [
	{"type": "coins", "amount": 15},
	{"type": "hints", "amount": 1},
	{"type": "coins", "amount": 20},
	{"type": "lives", "amount": 1},
	{"type": "coins", "amount": 30},
	{"type": "hints", "amount": 1},
	{"type": "coins", "amount": 60, "bonus_hints": 2},
]

const QUEST_POOL := [
	{"id": "match", "title": "Match 15 crystals", "goal": 15, "type": "coins", "amount": 15},
	{"id": "win", "title": "Complete 3 levels", "goal": 3, "type": "coins", "amount": 25},
	{"id": "stars", "title": "Earn 6 stars", "goal": 6, "type": "hints", "amount": 1},
	{"id": "combo", "title": "Reach a x3 combo", "goal": 1, "type": "coins", "amount": 20},
	{"id": "nohint", "title": "Win a level without hints", "goal": 1, "type": "coins", "amount": 20},
	{"id": "perfect", "title": "Get 3 stars on a level", "goal": 1, "type": "lives", "amount": 1},
	{"id": "gold", "title": "Collect 3 gold crystals", "goal": 3, "type": "coins", "amount": 25},
	{"id": "cascade", "title": "Trigger a cascade", "goal": 1, "type": "hints", "amount": 1},
]

const MILESTONES := [
	{"stars": 5, "type": "coins", "amount": 25},
	{"stars": 15, "type": "hints", "amount": 1},
	{"stars": 30, "type": "coins", "amount": 60},
	{"stars": 60, "type": "lives", "amount": 2},
	{"stars": 100, "type": "coins", "amount": 150},
	{"stars": 200, "type": "coins", "amount": 350},
	{"stars": 350, "type": "coins", "amount": 600},
	{"stars": 500, "type": "coins", "amount": 1000},
]

# Daily gift pick: three sealed gifts, one free pick a day (extra picks by video).
const PICK_POOL := [
	{"type": "coins", "amount": 20},
	{"type": "coins", "amount": 35},
	{"type": "coins", "amount": 50},
	{"type": "hints", "amount": 1},
	{"type": "hints", "amount": 2},
	{"type": "lives", "amount": 1},
]

# Welcome-back gift after a few days away (grows with the length of the break).
static func comeback_reward(away_days: int) -> Dictionary:
	if away_days >= 7:
		return {"type": "coins", "amount": 120, "bonus_hints": 3}
	if away_days >= 4:
		return {"type": "coins", "amount": 80, "bonus_hints": 2}
	return {"type": "coins", "amount": 50, "bonus_hints": 1}

# Three gifts for the daily pick; the same on every device for a given day.
static func pick_gifts(day: int) -> Array:
	var out: Array = []
	for k in range(3):
		out.append(PICK_POOL[(day + k * 2) % PICK_POOL.size()])
	return out

# Three different quests per day, the same on every device.
static func quests_for(day: int) -> Array:
	var out: Array = []
	for k in range(3):
		out.append(QUEST_POOL[(day * 2 + k) % QUEST_POOL.size()])
	return out

static func icon_for(reward_type: String) -> String:
	match reward_type:
		"hints":
			return "bulb"
		"lives":
			return "heart"
	return "coin"

static func describe(r: Dictionary) -> String:
	var amount := int(r.get("amount", 0))
	var text := ""
	match str(r.get("type", "coins")):
		"hints":
			text = "+%d hint%s" % [amount, "" if amount == 1 else "s"]
		"lives":
			text = "+%d li%s" % [amount, "fe" if amount == 1 else "ves"]
		_:
			text = "+%d coins" % amount
	if r.has("bonus_hints"):
		text += "  +%d hints" % int(r["bonus_hints"])
	return text

static func grant(save: SaveData, r: Dictionary) -> void:
	var amount := int(r.get("amount", 0))
	match str(r.get("type", "coins")):
		"hints":
			save.add_hints(amount)
		"lives":
			for _i in range(amount):
				save.add_life()
		_:
			save.add_coins(amount)
	if r.has("bonus_hints"):
		save.add_hints(int(r["bonus_hints"]))

# True when there is something to claim (drives the red dot on the Home button).
static func claimable(save: SaveData) -> bool:
	if save.login_available() or save.pick_available():
		return true
	save.ensure_quests()
	for q in quests_for(save.today()):
		var quest: Dictionary = q
		var id := str(quest["id"])
		if not save.quest_is_claimed(id) and save.quest_progress_of(id) >= int(quest["goal"]):
			return true
	for m in MILESTONES:
		var ms: Dictionary = m
		if int(save.data.total_stars) >= int(ms["stars"]) and not save.milestone_is_claimed(int(ms["stars"])):
			return true
	return false
