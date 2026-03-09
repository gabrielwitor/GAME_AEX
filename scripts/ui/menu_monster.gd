extends Node2D

@onready var monster_sprite: Sprite2D = $MonsterSprite
@onready var mouth_area: Area2D = $MouthArea

const MONSTER_SCALE := Vector2(0.38, 0.38)
const SPAWN_X_MIN := 1200.0
const SPAWN_X_MAX := 1870.0
const MAX_BOXES := 7
const SPAWN_INTERVAL := 2.0
const BOX_LIFESPAN := 12.0
const BOX_MODULATE := Color(0.6, 0.55, 0.5)

var texture_idle  = preload("res://assets/graphics/characters/monster_idle.png")
var texture_happy = preload("res://assets/graphics/characters/monster_happy.png")
var box_tex       = preload("res://assets/graphics/ui/kenney_ui-pack-adventure/Vector/button_brown.svg")
var font_future   = preload("res://assets/fonts/Kenney Future.ttf")

var audio_player: AudioStreamPlayer
var syllables := ["BO", "LA", "GA", "TO", "SA", "PI", "BA", "NA", "MA", "CA", "PA", "CO"]
var boxes: Array = []
var spawn_timer := 0.0

# Estado de drag
var grabbed_body: RigidBody2D = null
var drag_offset: Vector2 = Vector2.ZERO
var prev_mouse_pos: Vector2 = Vector2.ZERO
var drag_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Voice"
	add_child(audio_player)
	mouth_area.body_entered.connect(_on_body_entered)

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed and grabbed_body == null:
		# Procura blocos no ponto do mouse usando a física 2D
		var space = get_world_2d().direct_space_state
		var params = PhysicsPointQueryParameters2D.new()
		params.position = get_canvas_transform().affine_inverse() * event.global_position
		params.collision_mask = 1
		var results = space.intersect_point(params)
		for result in results:
			var body = result["collider"]
			if body is RigidBody2D and body.has_meta("syllable"):
				grabbed_body = body
				body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
				body.freeze = true
				drag_offset = get_global_mouse_position() - body.global_position
				prev_mouse_pos = get_global_mouse_position()
				drag_velocity = Vector2.ZERO
				# Consome o evento para não disparar botões do menu
				get_viewport().set_input_as_handled()
				break

	elif not event.pressed and grabbed_body != null:
		_release_body()

func _process(delta: float) -> void:
	# Spawning
	spawn_timer += delta
	if spawn_timer >= SPAWN_INTERVAL and boxes.size() < MAX_BOXES:
		spawn_timer = 0.0
		_spawn_box()

	# Arrastar bloco
	if grabbed_body and is_instance_valid(grabbed_body):
		var mouse_pos = get_global_mouse_position()
		drag_velocity = lerp(drag_velocity, (mouse_pos - prev_mouse_pos) / max(delta, 0.001), 0.75)
		prev_mouse_pos = mouse_pos
		grabbed_body.global_position = mouse_pos - drag_offset

	# Limpa caixas fora da tela
	for box in boxes.duplicate():
		if not is_instance_valid(box):
			boxes.erase(box)
		elif box.position.y > 1250:
			boxes.erase(box)
			box.queue_free()

func _release_body() -> void:
	if not grabbed_body or not is_instance_valid(grabbed_body):
		grabbed_body = null
		return

	grabbed_body.freeze = false
	grabbed_body.linear_velocity = drag_velocity * 0.85
	grabbed_body.angular_velocity = clamp(-drag_velocity.x * 0.015, -6.0, 6.0)
	grabbed_body = null

func _spawn_box() -> void:
	var syllable: String = syllables[randi() % syllables.size()]

	var box := RigidBody2D.new()
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.45
	mat.friction = 0.5
	box.physics_material_override = mat
	box.gravity_scale = 0.55
	box.linear_damp = 0.05
	box.position = Vector2(randf_range(SPAWN_X_MIN, SPAWN_X_MAX), -90.0)
	box.linear_velocity = Vector2(randf_range(-40.0, 40.0), 0.0)
	box.angular_velocity = randf_range(-1.2, 1.2)
	box.set_meta("syllable", syllable)

	# Fundo visual
	var nine := NinePatchRect.new()
	nine.texture = box_tex
	nine.patch_margin_left = 32
	nine.patch_margin_top = 32
	nine.patch_margin_right = 32
	nine.patch_margin_bottom = 32
	nine.size = Vector2(84, 84)
	nine.position = Vector2(-42, -42)
	nine.modulate = BOX_MODULATE
	nine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(nine)

	# Label
	var lbl := Label.new()
	lbl.text = syllable
	lbl.size = Vector2(84, 84)
	lbl.position = Vector2(-42, -48)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", font_future)
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.05))
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)

	# Colisão
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(84, 84)
	col.shape = shape
	box.add_child(col)

	# Timer de vida com fade
	get_tree().create_timer(BOX_LIFESPAN).timeout.connect(func():
		if is_instance_valid(box) and box != grabbed_body:
			var fade = create_tween()
			fade.tween_property(nine, "modulate:a", 0.0, 0.6)
			fade.tween_property(lbl, "modulate:a", 0.0, 0.6)
			await get_tree().create_timer(0.6).timeout
			if is_instance_valid(box):
				boxes.erase(box)
				box.queue_free()
	)

	add_child(box)
	boxes.append(box)

func _on_body_entered(body: Node) -> void:
	if not body.has_meta("syllable"):
		return

	# Limpa estado de drag se estava sendo arrastado
	if body == grabbed_body:
		grabbed_body = null

	var syllable: String = body.get_meta("syllable")
	var syl_path := "res://assets/audio/voice/syllables/" + syllable.to_lower() + ".mp3"
	if ResourceLoader.exists(syl_path):
		audio_player.stream = load(syl_path)
		audio_player.play()

	monster_sprite.texture = texture_happy
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(monster_sprite, "scale", MONSTER_SCALE * 1.25, 0.12)
	tween.tween_property(monster_sprite, "scale", MONSTER_SCALE, 0.2)

	boxes.erase(body)
	body.queue_free()

	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(monster_sprite) and monster_sprite.texture == texture_happy:
		monster_sprite.texture = texture_idle
