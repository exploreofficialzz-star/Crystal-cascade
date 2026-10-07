class_name Twists
extends RefCounted
## Names, colours and explanations for the level twists (see LevelGen).

const INFO := {
	"gold": {
		"label": "GOLD", "color": Color("#ffd34e"), "title": "GOLDEN CRYSTALS",
		"text": "Crystals with a golden ring pay bonus coins when they are cleared in a match.",
		"cass": "Golden rings pay extra coins!",
	},
	"cascade": {
		"label": "CASCADE", "color": Color("#ff944d"), "title": "CASCADE",
		"text": "Some triples are buried under other crystals. Lift the crystal on top and they clear by themselves, one after another!",
		"cass": "Some triples are buried. Dig them out!",
	},
	"mystery": {
		"label": "SHADOW", "color": Color("#b46cff"), "title": "SHADOW CRYSTALS",
		"text": "Shadow crystals hide their colour until they reach the top of a tube. Plan ahead, or ask Cass for a hint.",
		"cass": "Shadows hide their colours until they surface.",
	},
	"boss": {
		"label": "BOSS", "color": Color("#ff5b8a"), "title": "BOSS LEVEL",
		"text": "A bigger, tougher board. Clear it to open a Boss Chest with a big prize.",
		"cass": "Boss level. Big prize waiting!",
	},
}


static func label(t: String) -> String:
	if INFO.has(t):
		var d: Dictionary = INFO[t]
		return str(d["label"])
	return t.to_upper()


static func color_of(t: String) -> Color:
	if INFO.has(t):
		var d: Dictionary = INFO[t]
		return d["color"]
	return Color.WHITE


static func title_of(t: String) -> String:
	if INFO.has(t):
		var d: Dictionary = INFO[t]
		return str(d["title"])
	return t.to_upper()


static func text_of(t: String) -> String:
	if INFO.has(t):
		var d: Dictionary = INFO[t]
		return str(d["text"])
	return ""


static func cass_line(t: String) -> String:
	if INFO.has(t):
		var d: Dictionary = INFO[t]
		return str(d["cass"])
	return ""


# "SHADOW + GOLD" style summary of a level spec (empty for a plain level).
static func summary(spec: Dictionary) -> String:
	var parts: Array = []
	var list: Array = spec.get("twists", [])
	for t in list:
		if str(t) != "boss":
			parts.append(label(str(t)))
	return " + ".join(parts)
