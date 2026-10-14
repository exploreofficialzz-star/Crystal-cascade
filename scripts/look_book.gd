class_name LookBook
extends RefCounted

# Per-level variety so the game never looks the same for long. Every level gets a
# deterministic "look" on top of its theme: the colour mood of the room, the
# shape of the tubes, the cut of the crystals and a camera angle bias. Adjacent
# levels differ in several of these at once, and the combinations repeat only
# after hundreds of levels.
#
# Everything here is cosmetic: it never changes the rules or the board.

const TUBE_STYLES := 5      # 0 classic, 1 tapered, 2 flared, 3 hex, 4 chunky
const CRYSTAL_CUTS := 4     # 0 prism, 1 gem, 2 shard, 3 cube
const MOODS := 5            # hue rotations of the room lighting
const CAM_BIASES := 4

const MOOD_SHIFTS := [0.0, 0.07, -0.07, 0.14, -0.14]
const CAM_YAW := [0.0, 9.0, -9.0, 4.0]
const CAM_PITCH := [0.0, 2.5, -1.5, 4.0]

# Rim / glass accents per tube style group (only the tint changes).
const GLASS_TINTS := [
	Color(0.45, 0.72, 1.0),
	Color(0.62, 0.62, 1.0),
	Color(0.45, 0.95, 0.85),
	Color(1.0, 0.72, 0.85),
	Color(1.0, 0.85, 0.55),
]
const RIM_TINTS := [
	Color(0.55, 0.78, 1.0),
	Color(0.80, 0.62, 1.0),
	Color(0.55, 1.0, 0.85),
	Color(1.0, 0.65, 0.85),
	Color(1.0, 0.85, 0.50),
]

# Deterministic look for a level. `theme` is the level's theme index.
static func for_level(level: int, theme: int) -> Dictionary:
	var n: int = maxi(1, level)
	# Different strides per dimension keep neighbouring levels different everywhere.
	var tube_style: int = (n * 2 + n / 7) % TUBE_STYLES
	var cut: int = (n / 2 + n / 9) % CRYSTAL_CUTS
	var mood: int = (n / 3 + n / 11) % MOODS
	var cam: int = (n + n / 5) % CAM_BIASES
	var tint: int = (n * 3 + theme) % GLASS_TINTS.size()
	# The first levels stay classic so the tutorial looks exactly as it is taught.
	if n <= 3:
		tube_style = 0
		cut = 0
		mood = 0
		cam = 0
		tint = 0
	return {
		"tube_style": tube_style,
		"cut": cut,
		"mood_shift": float(MOOD_SHIFTS[mood]),
		"cam_yaw": float(CAM_YAW[cam]),
		"cam_pitch": float(CAM_PITCH[cam]),
		"glass_tint": GLASS_TINTS[tint],
		"rim_tint": RIM_TINTS[tint],
	}

# Rotates the hue of a light/sky colour (keeps brightness and saturation).
static func shift_hue(c: Color, amount: float) -> Color:
	if is_zero_approx(amount):
		return c
	return Color.from_hsv(fposmod(c.h + amount, 1.0), c.s, c.v, c.a)
