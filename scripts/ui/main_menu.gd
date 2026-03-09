extends Control

@onready var btn_play: TextureButton = $VBoxContainer/BtnPlay
@onready var btn_quit: TextureButton = $VBoxContainer/BtnQuit
@onready var title: Control = $Title

# Variáveis para animação de Tween
var _hover_scale := Vector2(1.1, 1.1)
var _normal_scale := Vector2(1.0, 1.0)
var _tween_duration := 0.2

var sfx_hover = preload("res://assets/audio/sfx/drop_001.ogg")
var sfx_click = preload("res://assets/audio/sfx/click_001.ogg")
var audio_player = AudioStreamPlayer.new()

func _ready() -> void:
	# Inicia a música de fundo usando o novo AutoLoad
	BgmController.play_music(preload("res://assets/audio/music/sergios_magic_dustbin.mp3"))
	
	# Conectando sinais de clique
	btn_play.pressed.connect(_on_btn_play_pressed)
	btn_quit.pressed.connect(_on_btn_quit_pressed)
	
	# Conectando hover animations do Play
	btn_play.mouse_entered.connect(_on_hover_enter.bind(btn_play))
	btn_play.mouse_exited.connect(_on_hover_exit.bind(btn_play))
	
	# Conectando hover animations do Quit
	btn_quit.mouse_entered.connect(_on_hover_enter.bind(btn_quit))
	btn_quit.mouse_exited.connect(_on_hover_exit.bind(btn_quit))
	
	# Ajustando pivots para escala centralizada após o VBox dimensionar as coisas
	call_deferred("_update_pivots")

func _update_pivots() -> void:
	btn_play.pivot_offset = btn_play.size / 2
	btn_quit.pivot_offset = btn_quit.size / 2
	# Configurando AudioPlayer
	add_child(audio_player)
	
	_animate_title()

func _animate_title() -> void:
	# Animação de flutuação e respiração para o título
	var tween = create_tween().set_loops()
	tween.tween_property(title, "position:y", title.position.y - 15, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title, "position:y", title.position.y, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var tween_scale = create_tween().set_loops()
	tween_scale.tween_property(title, "scale", Vector2(1.05, 1.05), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_scale.tween_property(title, "scale", Vector2(1.0, 1.0), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_hover_enter(btn: TextureButton) -> void:
	# Para não conflitar, matamos tweens que já estejam rodando no botão
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", _hover_scale, _tween_duration)
	_play_sfx(sfx_hover)

func _on_hover_exit(btn: TextureButton) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", _normal_scale, _tween_duration)

func _on_btn_play_pressed() -> void:
	_play_sfx(sfx_click)
	get_tree().change_scene_to_file("res://scenes/game/level_base.tscn")

func _on_btn_quit_pressed() -> void:
	_play_sfx(sfx_click)
	get_tree().quit()

func _play_sfx(stream: AudioStream) -> void:
	audio_player.stream = stream
	audio_player.play()
