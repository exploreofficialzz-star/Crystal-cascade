class_name DeviceProfile
extends RefCounted

# One place that decides how much the game asks of the phone.
#
#   lite    a weak phone (little RAM or few CPU cores), the player's "Lite
#           graphics" switch, or the start-up guard asking for it. Lite means:
#           no shader warm-up pass, a cheaper live avatar, a 30 fps cap and
#           ad formats that load later.
#   avatar  the live 3D avatar is switched off completely. Only the start-up
#           guard does this, after the game died twice while building it.

const LOW_RAM_MB := 3200
const LOW_CORE_COUNT := 4

static var _decided := false
static var _lite := false
static var _avatar_off := false
static var _ram_mb := 0

static func is_lite() -> bool:
	_decide()
	return _lite

static func avatar_off() -> bool:
	return _avatar_off

static func ram_mb() -> int:
	_decide()
	return _ram_mb

# Called once at start-up with the saved switch and the guard's verdict.
static func configure(force_lite: bool, no_avatar: bool) -> void:
	_decide()
	if force_lite:
		_lite = true
	_avatar_off = no_avatar

static func _decide() -> void:
	if _decided:
		return
	_decided = true
	if OS.get_name() != "Android":
		return
	var info: Dictionary = OS.get_memory_info()
	var physical: int = int(info.get("physical", -1))
	if physical > 0:
		_ram_mb = physical / 1048576
	var cores: int = OS.get_processor_count()
	if _ram_mb > 0 and _ram_mb <= LOW_RAM_MB:
		_lite = true
	elif cores > 0 and cores <= LOW_CORE_COUNT:
		_lite = true
