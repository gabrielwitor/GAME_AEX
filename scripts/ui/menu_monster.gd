extends Node2D

@onready var monster_sprite: Sprite2D = $MonsterSprite
@onready var mouth_area: Area2D = $MouthArea

const MONSTER_SCALE := Vector2(0.38, 0.38)
const SPAWN_X_MIN := 1200.0
const SPAWN_X_MAX := 1870.0
const MAX_BOXES := 7
const SPAWN_INTERVAL := 2.0
const BOX_LIFESPAN := 12.0

var texture_idle  = preload("res://assets/graphics/characters/monster_idle.png")
var texture_happy = preload("res://assets/graphics/characters/monster_happy.png")
var menu_block_scene = preload("res://scenes/ui/menu_block.tscn")

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

	var box: RigidBody2D = menu_block_scene.instantiate()
	box.position = Vector2(randf_range(SPAWN_X_MIN, SPAWN_X_MAX), -90.0)
	box.linear_velocity = Vector2(randf_range(-40.0, 40.0), 0.0)
	box.angular_velocity = randf_range(-1.2, 1.2)
	box.set_meta("syllable", syllable)
	box.get_node("Label").text = syllable

	# Timer de vida com fade
	var nine := box.get_node("Background")
	var lbl := box.get_node("Label")
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

	monster_sprite.texture = texture_happy
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(monster_sprite, "scale", MONSTER_SCALE * 1.25, 0.12)
	tween.tween_property(monster_sprite, "scale", MONSTER_SCALE, 0.2)

	boxes.erase(body)
	body.queue_free()

	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(monster_sprite) and monster_sprite.texture == texture_happy:
		monster_sprite.texture = texture_idle
