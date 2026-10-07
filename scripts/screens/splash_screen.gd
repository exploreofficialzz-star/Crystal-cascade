class_name SplashScreen
extends Control

# Launch cover: the same logo on the same dark background as the engine's boot
# splash, so the hand-over is seamless. No bar, no text, no tips. main.gd keeps it
# up only while the world is built behind it, then fades it away.

func setup() -> void:
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	Ui.full_rect(bg)
	bg.color = Color(0.035, 0.04, 0.1, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var logo := TextureRect.new()
	Ui.full_rect(logo)
	logo.texture = Ui.tex("res://assets/images/game_logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

func fade_out() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
