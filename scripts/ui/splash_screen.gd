extends Control

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
var _is_transitioning: bool = false

func _ready() -> void:
	video_player.finished.connect(_on_video_finished)

func _input(event: InputEvent) -> void:
	if _is_transitioning:
		return
		
	if event is InputEventMouseButton and event.pressed:
		_on_video_finished()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_video_finished()

func _on_video_finished() -> void:
	if _is_transitioning:
		return
		
	_is_transitioning = true
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
