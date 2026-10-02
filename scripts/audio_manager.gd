class_name AudioManager
extends Node

const SFX_VOICES := 4
const MUSIC_PATH := "res://assets/sounds/bg_music.mp3"
# Everything the game plays; preload_all() warms these during the splash screen.
const SFX_NAMES := ["tap", "match", "victory", "gameover", "coin",
	"ui_whoosh", "ui_chime", "chest_open", "streak_up", "tube_drop", "star_ping"]
const VOICE_NAMES := ["yay", "wow", "hmm", "think", "oh_no", "oops", "nope", "hello", "cheer", "giggle", "sigh"]

var music_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var enabled := true
var voice_enabled := true
var music_enabled := true
var _streams: Dictionary = {}
var _next_voice := 0
var _voice_block_until := 0

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = -2.0
	add_child(voice_player)
	for _i in range(SFX_VOICES):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		sfx_players.append(voice)
	var music := _load_stream(MUSIC_PATH)
	if music:
		# Imported MP3s do not loop by default, so the music used to play once
		# and then stop for good.
		if music is AudioStreamMP3:
			(music as AudioStreamMP3).loop = true
		music_player.stream = music
		music_player.volume_db = -9.0

func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream

func _sfx_stream(sfx_name: String) -> AudioStream:
	for ext in ["mp3", "wav", "ogg"]:
		var path := "res://assets/sounds/%s.%s" % [sfx_name, ext]
		if _streams.has(path):
			return _streams[path]
		var s := _load_stream(path)
		if s != null:
			_streams[path] = s
			return s
	return null

# Loads every sound once (called during the splash screen). Returns how many
# were found so the caller can step a progress bar.
func preload_one(index: int) -> void:
	var total_sfx := SFX_NAMES.size()
	if index < total_sfx:
		_sfx_stream(SFX_NAMES[index])
	elif index - total_sfx < VOICE_NAMES.size():
		_sfx_stream("cass_" + VOICE_NAMES[index - total_sfx])

func preload_count() -> int:
	return SFX_NAMES.size() + VOICE_NAMES.size()

func play_music() -> void:
	if music_enabled and music_player.stream and not music_player.playing:
		music_player.play()

func stop_music() -> void:
	music_player.stop()

func set_music(value: bool) -> void:
	music_enabled = value
	if value:
		play_music()
	else:
		stop_music()

# A pool of voices lets effects overlap (tap + match in the same frame) instead
# of the second one cutting the first off.
func play(sfx_name: String) -> void:
	if not enabled or sfx_players.is_empty():
		return
	var stream := _sfx_stream(sfx_name)
	if stream == null:
		return
	var voice: AudioStreamPlayer = sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % sfx_players.size()
	voice.stream = stream
	voice.play()

# Cass's voice lines. One line at a time; a new one is ignored while the
# previous is still playing, so quick event bursts never turn into chatter.
func play_voice(kind: String) -> float:
	if not enabled or not voice_enabled or kind == "":
		return 0.0
	var now := Time.get_ticks_msec()
	if now < _voice_block_until:
		return 0.0
	var stream := _sfx_stream("cass_" + kind)
	if stream == null:
		return 0.0
	voice_player.stream = stream
	voice_player.play()
	var length := stream.get_length()
	_voice_block_until = now + int(length * 900.0)
	return length
