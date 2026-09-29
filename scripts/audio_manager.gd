class_name AudioManager
extends Node

const SFX_VOICES := 4
const MUSIC_PATH := "res://assets/sounds/bg_music.mp3"

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var enabled := true
var music_enabled := true
var _streams: Dictionary = {}
var _next_voice := 0

func _ready() -> void:
    music_player = AudioStreamPlayer.new()
    add_child(music_player)
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
    var path := "res://assets/sounds/%s.mp3" % sfx_name
    var stream: AudioStream = _streams.get(path)
    if stream == null:
        stream = _load_stream(path)
        if stream == null:
            return
        _streams[path] = stream
    var voice: AudioStreamPlayer = sfx_players[_next_voice]
    _next_voice = (_next_voice + 1) % sfx_players.size()
    voice.stream = stream
    voice.play()
