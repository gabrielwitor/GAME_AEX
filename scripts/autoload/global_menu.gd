extends CanvasLayer

@onready var menu_panel = $MenuPanel
@onready var volume_slider = $MenuPanel/NinePatchRect/VBoxContainer/VolumeSlider
@onready var resume_btn = $MenuPanel/NinePatchRect/VBoxContainer/ResumeBtn
@onready var main_menu_btn = $MenuPanel/NinePatchRect/VBoxContainer/MainMenuBtn
@onready var quit_btn = $MenuPanel/NinePatchRect/VBoxContainer/QuitBtn

var audio_player = AudioStreamPlayer.new()

func _ready() -> void:
	# Hide the menu initially
	menu_panel.hide()
	
	# Try to get the Master bus volume
	var master_bus_idx = AudioServer.get_bus_index("Master")
	if master_bus_idx >= 0:
		var current_volume_db = AudioServer.get_bus_volume_db(master_bus_idx)
		volume_slider.value = db_to_linear(current_volume_db)
	
	# Connect signals
	volume_slider.value_changed.connect(_on_volume_changed)
	resume_btn.pressed.connect(_on_resume_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	var sfx_hover = preload("res://assets/audio/sfx/drop_001.ogg")
	var sfx_click = preload("res://assets/audio/sfx/click_001.ogg")

	var btns = [resume_btn, main_menu_btn, quit_btn]
	for btn in btns:
		btn.mouse_entered.connect(_on_hover_enter.bind(btn, sfx_hover))
		btn.mouse_exited.connect(_on_hover_exit.bind(btn))
		btn.pressed.connect(func(): _play_sfx(sfx_click))
		
	add_child(audio_player)

func _on_hover_enter(btn: TextureButton, sfx) -> void:
	btn.pivot_offset = btn.size / 2
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2)
	_play_sfx(sfx)

func _on_hover_exit(btn: TextureButton) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)

func _play_sfx(stream: AudioStream) -> void:
	audio_player.stream = stream
	audio_player.play()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		_toggle_menu()

func _toggle_menu() -> void:
	var menu_should_be_visible = not menu_panel.visible
	menu_panel.visible = menu_should_be_visible
	# Pause tree
	get_tree().paused = menu_should_be_visible
	if menu_should_be_visible:
		resume_btn.grab_focus()

func _on_volume_changed(value: float) -> void:
	var master_bus_idx = AudioServer.get_bus_index("Master")
	if master_bus_idx >= 0:
		AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(value))

func _on_resume_pressed() -> void:
	_toggle_menu()

func _on_main_menu_pressed() -> void:
	_toggle_menu()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
