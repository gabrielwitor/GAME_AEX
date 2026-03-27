extends CanvasLayer

signal next_level_requested
signal restart_requested

@onready var background: ColorRect = $Background
@onready var panel: NinePatchRect = $CenterContainer/NinePatchRect
@onready var congrat_label: Label = $CenterContainer/NinePatchRect/VBoxContainer/CongratLabel
@onready var target_image: TextureRect = $CenterContainer/NinePatchRect/VBoxContainer/TargetImage
@onready var btn_next: TextureButton = $CenterContainer/NinePatchRect/VBoxContainer/ButtonsVBox/BtnNextLevel
@onready var btn_next_label: Label = $CenterContainer/NinePatchRect/VBoxContainer/ButtonsVBox/BtnNextLevel/Label
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

func show_victory(image_path: String, is_final: bool = false) -> void:
	var tex = load(image_path)
	if tex:
		target_image.texture = tex
	
	# Configura estado específico do fim de jogo
	congrat_label.visible = is_final
	if is_final:
		btn_next_label.text = "JOGAR NOVAMENTE"
		# Reconecta o botão para reiniciar em vez de avançar
		if btn_next.pressed.is_connected(_on_btn_next_pressed):
			btn_next.pressed.disconnect(_on_btn_next_pressed)
		if not btn_next.pressed.is_connected(_on_btn_restart_pressed):
			btn_next.pressed.connect(_on_btn_restart_pressed)
	else:
		btn_next_label.text = "PROXIMO NIVEL"
		if btn_next.pressed.is_connected(_on_btn_restart_pressed):
			btn_next.pressed.disconnect(_on_btn_restart_pressed)
		if not btn_next.pressed.is_connected(_on_btn_next_pressed):
			btn_next.pressed.connect(_on_btn_next_pressed)
	
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

func _on_btn_restart_pressed() -> void:
	await get_tree().create_timer(0.15).timeout
	hide()
	restart_requested.emit()

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


func show_victory_texture(tex: Texture2D, is_final: bool = false) -> void:
	if tex:
		target_image.texture = tex
	# chama o restante da lógica existente de show_victory sem o load
	congrat_label.visible = is_final
	if is_final:
		btn_next_label.text = "JOGAR NOVAMENTE"
		if btn_next.pressed.is_connected(_on_btn_next_pressed):
			btn_next.pressed.disconnect(_on_btn_next_pressed)
		if not btn_next.pressed.is_connected(_on_btn_restart_pressed):
			btn_next.pressed.connect(_on_btn_restart_pressed)
	else:
		btn_next_label.text = "PROXIMO NIVEL"
		if btn_next.pressed.is_connected(_on_btn_restart_pressed):
			btn_next.pressed.disconnect(_on_btn_restart_pressed)
		if not btn_next.pressed.is_connected(_on_btn_next_pressed):
			btn_next.pressed.connect(_on_btn_next_pressed)

	background.color = Color(0, 0, 0, 0)
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.5, 0.5)
	show()

	var bg_tween = create_tween()
	bg_tween.tween_property(background, "color", Color(0, 0, 0, 0.85), 0.8)

	await get_tree().process_frame
	panel.pivot_offset = panel.size / 2

	var panel_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(panel, "scale", Vector2.ONE, 0.55)
	panel_tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.3)
