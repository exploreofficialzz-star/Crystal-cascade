class_name GameData
extends RefCounted

enum Status { IDLE, PLAYING, PAUSED, WON, LOST }
enum Reaction { NONE, SELECTED, DESELECTED, INVALID, MOVED, MATCHED, LOW_MOVES, WON, LOST }

const COLORS := ["red", "blue", "green", "yellow", "purple", "orange", "white"]
const COLOR_HEX := {
    "red": Color("#e94b5f"), "blue": Color("#3f9cff"), "green": Color("#45d483"),
    "yellow": Color("#ffd34e"), "purple": Color("#b46cff"), "orange": Color("#ff944d"),
    "white": Color("#e9f6ff")
}
const COLOR_NAMES := {
    "red": "Ruby", "blue": "Sapphire", "green": "Emerald", "yellow": "Citrine",
    "purple": "Amethyst", "orange": "Topaz", "white": "Diamond"
}

static func level_info(id: int) -> Dictionary:
    var tubes := 3
    var capacity := 6
    var colors := 2
    var gems := 6
    var moves := 12
    if id <= 5:
        pass
    elif id <= 15:
        tubes = 4; colors = 3; moves = 20
    elif id <= 30:
        tubes = 5; colors = 4; moves = 28
    elif id <= 50:
        tubes = 6; colors = 4; moves = 40
    elif id <= 75:
        tubes = 7; colors = 5; moves = 55
    elif id <= 100:
        tubes = 8; colors = 6; moves = 75
    else:
        var block := int((id - 101) / 20)
        colors = 7
        tubes = min(10, colors + (2 if block < 6 else 1))
        gems = clamp(6 + int(block / 2), 6, 12)
        capacity = gems
        var total := colors * gems
        var ratio := clamp(2.1 - block * 0.03, 1.35, 2.1)
        moves = int(ceil(total * ratio))
    var names: Array[String] = []
    for i in range(colors):
        names.append(COLORS[i])
    return {
        "id": id, "tubes": tubes, "capacity": capacity, "colors": names,
        "gems": gems, "moves": moves,
        "s1": int(ceil(moves * 0.2)), "s2": int(ceil(moves * 0.4)), "s3": int(ceil(moves * 0.6))
    }
