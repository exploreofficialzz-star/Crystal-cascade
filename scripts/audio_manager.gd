class_name AudioManager
extends Node

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var enabled := true
var music_enabled := true

func _ready() -> void:
    music_player = AudioStreamPlayer.new()
    sfx_player = AudioStreamPlayer.new()
    add_child(music_player)
    add_child(sfx_player)
    var music = load("res://assets/sounds/bg_music.mp3")
    if music:
        music_player.stream = music
        music_player.volume_db = -9.0

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

func play(name: String) -> void:
    if not enabled:
        return
    var stream = load("res://assets/sounds/%s.mp3" % name)
    if stream:
        sfx_player.stream = stream
        sfx_player.play()
