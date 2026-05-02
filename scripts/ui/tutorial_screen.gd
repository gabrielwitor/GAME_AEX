extends CanvasLayer
## Tutorial interativo do Monstrinho Faminto.
## Exibe o jogo em modo auto-play, narrando as instruções passo a passo.
## Disparado pelo main_menu quando tutorial_seen_this_session == false.

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------
const BUBBLE_SHOW_DURATION := 0.3
const BLOCK_DRAG_DURATION  := 0.9
const ARROW_FLOAT_DELTA    := 12.0
const ARROW_FLOAT_PERIOD   := 1.4

const TUTORIAL_WORD        := "BOLA"
const TUTORIAL_SYLLABLES   := ["BO", "LA"]
const TUTORIAL_IMAGE       := "res://assets/graphics/objects/bola.png"

# ---------------------------------------------------------------------------
# Áudios de narração (carregados sob demanda para não bloquear a inicialização)
# ---------------------------------------------------------------------------
const AUDIO_PATH := "res://assets/audio/voice/tutorial/"

# ---------------------------------------------------------------------------
# Referências de nós (todos criados proceduralmente para evitar dependência de .tscn)
# ---------------------------------------------------------------------------
@onready var _level_base: Node2D           = $LevelBase
@onready var _overlay: ColorRect           = $Overlay
@onready var _arrow: TextureRect           = $Arrow
@onready var _speech_panel: MarginContainer  = $SpeechBubble
@onready var _speech_label: RichTextLabel  = $SpeechBubble/MarginContainer/RichTextLabel
@onready var _end_panel: CenterContainer   = $EndPanel
@onready var _btn_replay: TextureButton    = $EndPanel/NinePatchRect/VBoxContainer/BtnReplay
@onready var _btn_continue: TextureButton  = $EndPanel/NinePatchRect/VBoxContainer/BtnContinue
@onready var _narrator: AudioStreamPlayer  = $Narrator

var audio_player = AudioStreamPlayer.new()

# Tweens de loop que precisam ser mortos ao final
var _arrow_tween: Tween
var _highlight_tween: Tween

# Referência ao bloco destacado atualmente
var _highlighted_block: Node2D

# ---------------------------------------------------------------------------
# Inicialização
# ---------------------------------------------------------------------------
func _ready() -> void:
	# Garante que o overlay e painel final começam invisíveis
	_overlay.modulate.a       = 0.0
	_speech_panel.modulate.a  = 0.0
	_speech_panel.scale       = Vector2.ZERO
	_end_panel.modulate.a     = 0.0
	_end_panel.visible        = false
	_arrow.visible            = false

	add_child(audio_player)
	var sfx_hover = preload("res://assets/audio/sfx/drop_001.ogg")
	var sfx_click = preload("res://assets/audio/sfx/click_001.ogg")

	var btns = [_btn_replay, _btn_continue]
	for btn in btns:
		btn.mouse_entered.connect(_on_hover_enter.bind(btn, sfx_hover))
		btn.mouse_exited.connect(_on_hover_exit.bind(btn))
		btn.pressed.connect(func(): _play_sfx(sfx_click))

	# Conecta botões do painel final
	_btn_replay.pressed.connect(_on_btn_replay_pressed)
	_btn_continue.pressed.connect(_on_btn_continue_pressed)

	# Aguarda 1 frame para o level_base terminar seu _ready()
	await get_tree().process_frame
	_level_base.enter_tutorial_mode()

	# Inicia a sequência do tutorial
	_run_tutorial()

# ---------------------------------------------------------------------------
# Sequência principal (corrotina linear)
# ---------------------------------------------------------------------------
func _run_tutorial() -> void:
	await _step_intro()
	await _step_show_balloon()
	await _step_show_blocks()
	await _step_drag_first_syllable()
	await _step_drag_second_syllable()
	await _step_word_complete()
	await _show_end_panel()

# ---------------------------------------------------------------------------
# Passos do tutorial
# ---------------------------------------------------------------------------
func _step_intro() -> void:
	# Leve escurecimento do fundo para destacar a narração
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_overlay, "modulate:a", 0.35, 0.6)
	await t.finished

	await _show_speech("Olá! Vou te mostrar como jogar!")
	await _play_narration("tutorial_01_intro.mp3")
	await _hide_speech()

func _step_show_balloon() -> void:
	# Aponta a seta para o balão de pensamento do monstro
	var balloon_screen_pos: Vector2 = _level_base.get_thought_balloon_screen_pos()
	_place_arrow(balloon_screen_pos + Vector2(0, -90), true)

	await _show_speech("O Monstrinho está com fome! Veja o que ele quer comer.")
	await _play_narration("tutorial_02_balloon.mp3")

	_stop_arrow()
	await _hide_speech()

func _step_show_blocks() -> void:
	# Aponta a seta para a área dos blocos
	var blocks_screen_pos := Vector2(960, 900)
	_place_arrow(blocks_screen_pos, true)

	# Pisca todos os blocos
	for block in _level_base.get_syllable_blocks():
		_pulse_node(block, 1.18, 0.5)

	await _show_speech("Aqui embaixo estão as sílabas. Você precisa encontrar as certas!", "top")
	await _play_narration("tutorial_03_blocks.mp3")

	_stop_arrow()
	await _hide_speech()
	
	# Retira o escurecimento do fundo para a demonstração do gameplay
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_overlay, "modulate:a", 0.0, 0.4)

func _step_drag_first_syllable() -> void:
	var syl := TUTORIAL_SYLLABLES[0]  # "BO"
	var block: SyllableBlock = _level_base.find_block_by_syllable(syl)

	if not is_instance_valid(block):
		return

	# Destaque no bloco correto
	_highlight_block(block)
	_place_arrow(block.global_position, true)

	await _show_speech("Encontre a sílaba [color=#ffdd00]%s[/color] e arraste até a boca do monstro!" % syl, "top")
	await _play_narration("tutorial_04_first_syllable.mp3")

	_stop_arrow()
	await _hide_speech()
	_remove_highlight()

	# Simula o drag até a boca
	await _auto_drag_block(block)
	# Notifica o level_base para processar como se fosse um drop real
	await _level_base.tutorial_drop_block(block)

func _step_drag_second_syllable() -> void:
	var syl := TUTORIAL_SYLLABLES[1]  # "LA"
	var block: SyllableBlock = _level_base.find_block_by_syllable(syl)

	if not is_instance_valid(block):
		return

	await get_tree().create_timer(0.6).timeout

	_highlight_block(block)
	_place_arrow(block.global_position, true)

	await _show_speech("Agora arraste a sílaba [color=#ffdd00]%s[/color]!" % syl, "left")
	await _play_narration("tutorial_05_second_syllable.mp3")

	_stop_arrow()
	await _hide_speech()
	_remove_highlight()

	await _auto_drag_block(block)
	await _level_base.tutorial_drop_block(block)

func _step_word_complete() -> void:
	await get_tree().create_timer(1.5).timeout
	await _show_speech("Muito bem! Você formou a palavra [color=#ffdd00]BOLA[/color]! Agora é sua vez!", "left")
	await _play_narration("tutorial_06_complete.mp3")
	await _hide_speech()

func _show_end_panel() -> void:
	# Escurece um pouco mais o overlay para o painel final se destacar
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_overlay, "modulate:a", 0.72, 0.5)
	await t.finished

	_end_panel.visible = true
	_end_panel.pivot_offset = _end_panel.size / 2

	var pt := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pt.tween_property(_end_panel, "modulate:a", 1.0, 0.45)
	await pt.finished

# ---------------------------------------------------------------------------
# Ações dos botões
# ---------------------------------------------------------------------------
func _on_btn_replay_pressed() -> void:
	# Pausa para o som tocar antes de mudar de cena
	await get_tree().create_timer(0.15).timeout
	# Reinicia a cena do tutorial do zero
	get_tree().reload_current_scene()

func _on_btn_continue_pressed() -> void:
	# Pausa para o som tocar antes de mudar de cena
	await get_tree().create_timer(0.15).timeout
	# Marca como visto e vai ao jogo
	WordData.tutorial_seen_this_session = true
	get_tree().change_scene_to_file("res://scenes/game/level_base.tscn")

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

# ---------------------------------------------------------------------------
# Helpers de UI
# ---------------------------------------------------------------------------
func _show_speech(text: String, pos_type: String = "bottom") -> void:
	_speech_label.text = "[center]" + text + "[/center]"
	_speech_panel.pivot_offset = _speech_panel.size / 2.0
	
	var panel_size = _speech_panel.size
	var target_scale = 0.75
	var visual_size = panel_size * target_scale
	
	# Ajusta a posição base do painel dependendo do tipo
	# O pivô é no centro. Centro do nó = position + panel_size / 2
	if pos_type == "bottom":
		var center_x = 1920.0 / 2.0
		var center_y = 1080.0 - 40.0 - (visual_size.y / 2.0)
		_speech_panel.position = Vector2(center_x, center_y) - panel_size / 2.0
	elif pos_type == "top":
		var center_x = 1920.0 / 2.0
		var center_y = 50.0 + (visual_size.y / 2.0)
		_speech_panel.position = Vector2(center_x, center_y) - panel_size / 2.0
	elif pos_type == "left":
		# Alinhado à esquerda
		var center_x = 60.0 + (visual_size.x / 2.0)
		var center_y = 1080.0 / 2.0
		_speech_panel.position = Vector2(center_x, center_y) - panel_size / 2.0
		
	_speech_panel.scale  = Vector2(0.6, 0.6)

	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_speech_panel, "scale", Vector2(0.75, 0.75), BUBBLE_SHOW_DURATION)
	t.parallel().tween_property(_speech_panel, "modulate:a", 1.0, BUBBLE_SHOW_DURATION * 0.8)
	await t.finished

func _hide_speech() -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(_speech_panel, "modulate:a", 0.0, 0.2)
	await t.finished

# ---------------------------------------------------------------------------
# Narração
# ---------------------------------------------------------------------------
func _play_narration(filename: String) -> void:
	var path := AUDIO_PATH + filename
	if not ResourceLoader.exists(path):
		# Sem áudio: aguarda 2 s como fallback para o jogador ler o texto
		await get_tree().create_timer(2.0).timeout
		return

	_narrator.stream = load(path)
	_narrator.play()
	await _narrator.finished

# ---------------------------------------------------------------------------
# Seta indicadora
# ---------------------------------------------------------------------------
func _place_arrow(target_pos: Vector2, point_down: bool = true) -> void:
	_arrow.visible  = true
	_arrow.flip_v   = point_down
	
	var offset = Vector2(0, -60) if point_down else Vector2(0, 60)
	var base_pos = target_pos + offset - _arrow.size / 2
	_arrow.position = base_pos

	# Para tween anterior se existir
	if _arrow_tween and _arrow_tween.is_valid():
		_arrow_tween.kill()

	# Animação flutuante em loop
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.tween_property(_arrow, "position:y", base_pos.y - ARROW_FLOAT_DELTA, ARROW_FLOAT_PERIOD)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arrow_tween.tween_property(_arrow, "position:y", base_pos.y, ARROW_FLOAT_PERIOD)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_arrow() -> void:
	if _arrow_tween and _arrow_tween.is_valid():
		_arrow_tween.kill()
	var t := create_tween()
	t.tween_property(_arrow, "modulate:a", 0.0, 0.2)
	await t.finished
	_arrow.visible = false
	_arrow.modulate.a = 1.0

# ---------------------------------------------------------------------------
# Destaque de bloco (glow pulsante via scale loop)
# ---------------------------------------------------------------------------
func _highlight_block(block: Node2D) -> void:
	_remove_highlight()
	_highlighted_block = block

	_highlight_tween = create_tween().set_loops()
	_highlight_tween.tween_property(block, "scale", Vector2(1.2, 1.2), 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.tween_property(block, "scale", Vector2(1.0, 1.0), 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _remove_highlight() -> void:
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
	if is_instance_valid(_highlighted_block):
		_highlighted_block.scale = Vector2.ONE
	_highlighted_block = null

# ---------------------------------------------------------------------------
# Pulse único (para brilho nos blocos durante a etapa de apresentação)
# ---------------------------------------------------------------------------
func _pulse_node(node: Node2D, scale_target: float, duration: float) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "scale", Vector2(scale_target, scale_target), duration)
	t.tween_property(node, "scale", Vector2.ONE, duration)

# ---------------------------------------------------------------------------
# Auto-drag: move o bloco até a boca com Tween
# ---------------------------------------------------------------------------
func _auto_drag_block(block: Node2D) -> void:
	var mouth_pos: Vector2 = _level_base.get_mouth_global_position()

	# Desabilita completamente o input (set_process_input cobre _input(),
	# input_pickable cobre o sinal input_event da Area2D)
	block.set_process_input(false)
	if block is Area2D:
		block.input_pickable = false
	block.z_index = 10

	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(block, "global_position", mouth_pos, BLOCK_DRAG_DURATION)
	await t.finished

	block.z_index = 0
