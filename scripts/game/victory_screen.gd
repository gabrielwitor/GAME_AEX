extends CanvasLayer

signal next_level_requested

@onready var background: ColorRect = $Background
@onready var panel: NinePatchRect = $CenterContainer/NinePatchRect
@onready var target_image: TextureRect = $CenterContainer/NinePatchRect/VBoxContainer/TargetImage
@onready var btn_next: TextureButton = $CenterContainer/NinePatchRect/VBoxContainer/ButtonsVBox/BtnNextLevel
@onready var btn_menu: TextureButton = $CenterContainer/NinePatchRect/VBoxContainer/ButtonsVBox/BtnMenu

var audio_player = AudioStreamPlayer.new()

func _ready() -> void:
	hide()
	
	add_child(audio_player)
	
	var sfx_hover = preload("res://assets/audio/sfx/drop_001.ogg")
	var sfx_click = preload("res://assets/audio/sfx/click_001.ogg")
	
	var btns = [btn_next, btn_menu]
	for btn in btns:
		btn.mouse_entered.connect(_on_hover_enter.bind(btn, sfx_hover))
		btn.mouse_exited.connect(_on_hover_exit.bind(btn))
		btn.pressed.connect(func(): _play_sfx(sfx_click))

	btn_next.pressed.connect(_on_btn_next_pressed)
	btn_menu.pressed.connect(_on_btn_menu_pressed)

func show_victory(image_path: String) -> void:
	var tex = load(image_path)
	if tex:
		target_image.texture = tex
	
	# Reseta o fundo e esconde o painel antes de mostrar
	background.color = Color(0, 0, 0, 0)
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.5, 0.5)
	show()
	
	# Anima o escurecimento do fundo
	var bg_tween = create_tween()
	bg_tween.tween_property(background, "color", Color(0, 0, 0, 0.85), 0.8)
	
	# Aguarda 1 frame para o layout calcular o tamanho real do painel
	await get_tree().process_frame
	panel.pivot_offset = panel.size / 2
	
	# Pop-in do painel do centro da tela
	var panel_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(panel, "scale", Vector2.ONE, 0.55)
	panel_tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.3)

func _on_btn_next_pressed() -> void:
	await get_tree().create_timer(0.15).timeout
	hide()
	next_level_requested.emit()

func _on_btn_menu_pressed() -> void:
	# Pausa para o som tocar antes de mudar de cena
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

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
