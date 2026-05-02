extends CanvasLayer

@onready var side_panel = $SidePanel
@onready var menu_panel = $SidePanel/MenuPanel
@onready var music_slider = $SidePanel/MenuPanel/VBoxContainer/HBoxContainer/MusicBox/MusicSlider
@onready var voice_slider = $SidePanel/MenuPanel/VBoxContainer/HBoxContainer/VoiceBox/VoiceSlider
@onready var main_menu_btn = $SidePanel/MenuPanel/VBoxContainer/MainMenuBtn
@onready var quit_btn = $SidePanel/MenuPanel/VBoxContainer/QuitBtn
@onready var toggle_btn = $SidePanel/ToggleBtn

var audio_player = AudioStreamPlayer.new()
var is_menu_open = false
var panel_width = 300.0
var tween: Tween

func _ready() -> void:
	# Garante que os buses existem ao rodar (criados na primeira vez)
	_ensure_bus("Music")
	_ensure_bus("Voice")
	
	# Inicia a música bem baixa (5%)
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(0.05))

	# Define a largura de abertura baseada no tamanho configurado no editor
	panel_width = menu_panel.offset_right

	# Configure panel initial state (closed)
	side_panel.offset_left = 0
	side_panel.offset_right = 0
	is_menu_open = false
	
	# Lê volumes atuais dos buses e sincroniza os sliders
	music_slider.value = _get_bus_linear("Music")
	voice_slider.value = _get_bus_linear("Voice")
	
	# Conecta sinais
	music_slider.value_changed.connect(_on_music_volume_changed)
	voice_slider.value_changed.connect(_on_voice_volume_changed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	toggle_btn.pressed.connect(_on_toggle_pressed)

	var sfx_hover = preload("res://assets/audio/sfx/drop_001.ogg")
	var sfx_click = preload("res://assets/audio/sfx/click_001.ogg")

	var btns = [main_menu_btn, quit_btn, toggle_btn]
	for btn in btns:
		btn.mouse_entered.connect(_on_hover_enter.bind(btn, sfx_hover))
		btn.mouse_exited.connect(_on_hover_exit.bind(btn))
		btn.pressed.connect(func(): _play_sfx(sfx_click))
		
	add_child(audio_player)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

func _get_bus_linear(bus_name: String) -> float:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

func _on_hover_enter(btn: TextureButton, sfx) -> void:
	btn.pivot_offset = btn.size / 2
	var t = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.2)
	_play_sfx(sfx)

func _on_hover_exit(btn: TextureButton) -> void:
	var t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)

func _play_sfx(stream: AudioStream) -> void:
	audio_player.stream = stream
	audio_player.play()

func _on_toggle_pressed() -> void:
	_toggle_menu()

func _toggle_menu() -> void:
	is_menu_open = !is_menu_open
	
	if tween and tween.is_valid():
		tween.kill()
		
	tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_parallel(true)
	
	var target_offset = -panel_width if is_menu_open else 0.0
	tween.tween_property(side_panel, "offset_left", target_offset, 0.4)
	tween.tween_property(side_panel, "offset_right", target_offset, 0.4)

func _on_music_volume_changed(value: float) -> void:
	var idx = AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))

func _on_voice_volume_changed(value: float) -> void:
	var idx = AudioServer.get_bus_index("Voice")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))

func _on_main_menu_pressed() -> void:
	if is_menu_open:
		_toggle_menu()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
