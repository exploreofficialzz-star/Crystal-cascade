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
