extends Node2D

@onready var monster_mouth: Area2D = $MonsterMouth
@onready var monster_sprite: Sprite2D = $MonsterMouth/Sprite2D
@onready var thought_balloon: Sprite2D = $MonsterMouth/ThoughtBalloon
@onready var target_image: Sprite2D = $MonsterMouth/ThoughtBalloon/TargetImage
@onready var progress_container: HBoxContainer = $MonsterMouth/ThoughtBalloon/WordProgressContainer
@onready var blocks_container: Node2D = $SyllableBlocks

var texture_idle = preload("res://assets/graphics/characters/monster_idle.png")
var texture_open = preload("res://assets/graphics/characters/monster_open.png")
var texture_sad = preload("res://assets/graphics/characters/monster_sad.png")
var texture_happy = preload("res://assets/graphics/characters/monster_happy.png")
var box_texture = preload("res://assets/graphics/ui/kenney_ui-pack-adventure/Vector/button_brown.svg")
var font_future = preload("res://assets/fonts/Kenney Future.ttf")

var sfx_pop = preload("res://assets/audio/sfx/monster/pop.wav")
var sfx_chew = preload("res://assets/audio/sfx/monster/chew.wav")
var sfx_spit = preload("res://assets/audio/sfx/monster/spit.wav")
var sfx_gulp = preload("res://assets/audio/sfx/monster/gulp.wav")

var audio_player_pop: AudioStreamPlayer
var audio_player_chew: AudioStreamPlayer
var audio_player_spit: AudioStreamPlayer
var audio_player_gulp: AudioStreamPlayer

var sfx_hooray = preload("res://assets/audio/sfx/monster/hooray.ogg")
var audio_player_hooray: AudioStreamPlayer

var audio_player_syllable: AudioStreamPlayer
var audio_player_word: AudioStreamPlayer

var victory_screen_scene = preload("res://scenes/game/victory_screen.tscn")
var victory_screen: CanvasLayer

var syllable_block_scene = preload("res://scenes/game/syllable_block.tscn")

var current_level: int = 1
var levels_data: Array = []
var current_level_data: Dictionary = {}

var word_syllables: Array[String] = []
var current_syllable_idx: int = 0

## Quando true, o input do jogador fica desabilitado (usado pelo tutorial).
var tutorial_mode: bool = false

func _ready() -> void:
	audio_player_pop = AudioStreamPlayer.new()
	audio_player_pop.stream = sfx_pop
	add_child(audio_player_pop)
	
	audio_player_chew = AudioStreamPlayer.new()
	audio_player_chew.stream = sfx_chew
	add_child(audio_player_chew)
	
	audio_player_spit = AudioStreamPlayer.new()
	audio_player_spit.stream = sfx_spit
	add_child(audio_player_spit)
	
	audio_player_gulp = AudioStreamPlayer.new()
	audio_player_gulp.stream = sfx_gulp
	add_child(audio_player_gulp)
	
	audio_player_hooray = AudioStreamPlayer.new()
	audio_player_hooray.stream = sfx_hooray
	audio_player_hooray.bus = "Voice"
	add_child(audio_player_hooray)
	
	audio_player_syllable = AudioStreamPlayer.new()
	audio_player_syllable.bus = "Voice"
	add_child(audio_player_syllable)
	
	audio_player_word = AudioStreamPlayer.new()
	audio_player_word.bus = "Voice"
	add_child(audio_player_word)
	
	victory_screen = victory_screen_scene.instantiate()
	add_child(victory_screen)
	victory_screen.next_level_requested.connect(_on_next_level_requested)

	# Animação flutuante do balão de pensamento
	var tween_balloon = create_tween().set_loops()
	tween_balloon.tween_property(thought_balloon, "position:y", thought_balloon.position.y - 15, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_balloon.tween_property(thought_balloon, "position:y", thought_balloon.position.y, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	_load_levels_data()
	_setup_level(current_level)

func _load_levels_data() -> void:
	var file = FileAccess.open("res://data/levels.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json is Array:
			levels_data = json

func _setup_level(level_idx: int) -> void:
	# Limpa os containers ao trocar de fase (remoção síncrona para evitar conflito com add_child)
	for child in progress_container.get_children():
		progress_container.remove_child(child)
		child.free()
	for child in blocks_container.get_children():
		blocks_container.remove_child(child)
		child.free()
		
	current_syllable_idx = 0
	word_syllables.clear()
	
	# Encontra os dados da fase no JSON
	var found_level = false
	for l_data in levels_data:
		if l_data["level"] == level_idx:
			current_level_data = l_data
			found_level = true
			break
			
	if not found_level:
		# Jogo concluído: volta ao menu
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		return

	# Popula as sílabas da palavra
	for s in current_level_data["syllables"]:
		word_syllables.append(s)

	# Atualiza a imagem no balão de pensamento com a imagem correta do nível
	var img_path = current_level_data["image_path"]
	if ResourceLoader.exists(img_path):
		target_image.texture = load(img_path)

	# Cria os slots do balão de progresso dinamicamente
	for i in range(word_syllables.size()):
		var patch = NinePatchRect.new()
		patch.texture = box_texture
		patch.patch_margin_left = 32
		patch.patch_margin_top = 32
		patch.patch_margin_right = 32
		patch.patch_margin_bottom = 32
		patch.custom_minimum_size = Vector2(140, 140)
		
		var lbl = Label.new()
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", font_future)
		lbl.add_theme_font_size_override("font_size", 60)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.add_theme_color_override("font_outline_color", Color(0.3, 0.15, 0.05))
		lbl.add_theme_constant_override("outline_size", 10)
		
		patch.add_child(lbl)
		progress_container.add_child(patch)

	_update_word_progress()
	
	# Mistura sílabas corretas + distratores e posiciona os blocos no chão
	var all_blocks_text: Array[String] = []
	all_blocks_text.append_array(word_syllables)
	all_blocks_text.append_array(current_level_data["distractors"])
	all_blocks_text.shuffle()
	
	var available_width = 1800
	var spacing = float(available_width) / float(all_blocks_text.size() + 1)
	for i in range(all_blocks_text.size()):
		var block = syllable_block_scene.instantiate()
		block.syllable_text = all_blocks_text[i]
		block.position = Vector2(60 + spacing * (i + 1), 762)
		blocks_container.add_child(block)
		block.syllable_grabbed.connect(_on_syllable_grabbed)
		block.syllable_dropped.connect(_on_syllable_dropped)
		
	monster_sprite.texture = texture_idle

func _on_next_level_requested() -> void:
	current_level += 1
	_setup_level(current_level)

func _update_word_progress() -> void:
	for i in range(word_syllables.size()):
		var patch = progress_container.get_child(i)
		var lbl = patch.get_child(0)
		
		if i < current_syllable_idx:
			patch.modulate = Color(1.0, 1.0, 1.0, 1.0)
			lbl.text = word_syllables[i]
		else:
			patch.modulate = Color(1.0, 1.0, 1.0, 0.3)
			lbl.text = ""

func _on_syllable_grabbed(_block: SyllableBlock) -> void:
	if tutorial_mode:
		return
	monster_sprite.texture = texture_open
	audio_player_pop.play()
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(monster_sprite, "scale", Vector2(1.05, 1.05), 0.15)

func _on_syllable_dropped(block: SyllableBlock) -> void:
	if tutorial_mode:
		return
	monster_sprite.texture = texture_idle
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(monster_sprite, "scale", Vector2(1.0, 1.0), 0.15)
	
	var is_inside_mouth = false
	for area in block.get_overlapping_areas():
		if area == monster_mouth:
			is_inside_mouth = true
			break
			
	if is_inside_mouth:
		if current_syllable_idx < word_syllables.size():
			var expected_syllable = word_syllables[current_syllable_idx]
			
			# Pronuncia a sílaba ao cair na boca (certa ou errada)
			var syl_path = "res://assets/audio/voice/syllables/" + block.syllable_text.to_lower() + ".mp3"
			if ResourceLoader.exists(syl_path):
				audio_player_syllable.stream = load(syl_path)
				audio_player_syllable.play()
			
			if block.syllable_text == expected_syllable:
				monster_sprite.texture = texture_happy
				audio_player_chew.play()
				get_tree().create_timer(0.4).timeout.connect(audio_player_gulp.play)
				
				# Anima o bloco sendo engolido
				var block_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				block_tween.tween_property(block, "scale", Vector2.ZERO, 0.2)
				block_tween.finished.connect(block.queue_free)
				
				current_syllable_idx += 1
				_update_word_progress()
				
				if current_syllable_idx >= word_syllables.size():
					# Palavra completa: comemoração!
					await get_tree().create_timer(1.2).timeout
					audio_player_hooray.play()
					
					var word_path = current_level_data["word_audio"]
					if ResourceLoader.exists(word_path):
						await get_tree().create_timer(1.0).timeout
						audio_player_word.stream = load(word_path)
						audio_player_word.play()
					
					victory_screen.show_victory(current_level_data["image_path"])
				
				# Volta o monstrinho ao estado padrão após 1s
				await get_tree().create_timer(1.0).timeout
				if monster_sprite.texture == texture_happy:
					monster_sprite.texture = texture_idle
			else:
				# Sílaba errada: monstro fica triste e cuspirá de volta
				monster_sprite.texture = texture_sad
				audio_player_spit.play()
				block.return_to_home()
				
				await get_tree().create_timer(1.0).timeout
				if monster_sprite.texture == texture_sad:
					monster_sprite.texture = texture_idle
		else:
			block.return_to_home()
	else:
		# Bloco solto fora da boca: volta à posição inicial
		block.return_to_home()

# ---------------------------------------------------------------------------
# API pública para o tutorial
# ---------------------------------------------------------------------------

## Ativa o modo tutorial: desabilita input dos blocos e esconde a tela de vitória.
func enter_tutorial_mode() -> void:
	tutorial_mode = true
	# Esconde a tela de vitória — não deve aparecer durante o tutorial
	if is_instance_valid(victory_screen):
		victory_screen.hide()
	# Desabilita input em todos os blocos já criados pelo _ready()
	for block in blocks_container.get_children():
		block.set_process_input(false)
		# Area2D: desabilita o sinal input_event também
		if block is Area2D:
			block.input_pickable = false

## Retorna a posição de tela do balão de pensamento (para a seta do tutorial).
func get_thought_balloon_screen_pos() -> Vector2:
	return thought_balloon.get_global_transform_with_canvas().origin

## Retorna a posição global do centro da boca do monstro.
func get_mouth_global_position() -> Vector2:
	return monster_mouth.global_position

## Retorna todos os SyllableBlocks filhos do container de blocos.
func get_syllable_blocks() -> Array:
	return blocks_container.get_children()

## Procura um SyllableBlock pela sílaba exata.
func find_block_by_syllable(syllable: String) -> SyllableBlock:
	for child in blocks_container.get_children():
		if child is SyllableBlock and child.syllable_text == syllable:
			return child
	return null

## Processa um drop simulado pelo tutorial (o bloco já está sobre a boca).
func tutorial_drop_block(block: SyllableBlock) -> void:
	if current_syllable_idx >= word_syllables.size():
		return

	var expected := word_syllables[current_syllable_idx]

	# Pronúncia da sílaba
	var syl_path := "res://assets/audio/voice/syllables/" + block.syllable_text.to_lower() + ".mp3"
	if ResourceLoader.exists(syl_path):
		audio_player_syllable.stream = load(syl_path)
		audio_player_syllable.play()

	if block.syllable_text == expected:
		monster_sprite.texture = texture_happy
		audio_player_chew.play()
		get_tree().create_timer(0.4).timeout.connect(audio_player_gulp.play)

		var bt := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		bt.tween_property(block, "scale", Vector2.ZERO, 0.2)
		bt.finished.connect(block.queue_free)

		current_syllable_idx += 1
		_update_word_progress()

		if current_syllable_idx >= word_syllables.size():
			await get_tree().create_timer(1.2).timeout
			audio_player_hooray.play()
			var word_path: String = current_level_data.get("word_audio", "")
			if ResourceLoader.exists(word_path):
				await get_tree().create_timer(0.9).timeout
				audio_player_word.stream = load(word_path)
				audio_player_word.play()

		await get_tree().create_timer(1.0).timeout
		if monster_sprite.texture == texture_happy:
			monster_sprite.texture = texture_idle
