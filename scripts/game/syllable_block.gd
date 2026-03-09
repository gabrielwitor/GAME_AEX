extends Area2D
class_name SyllableBlock

signal syllable_dropped(syllable_block)
signal syllable_grabbed(syllable_block)

@export var syllable_text: String = "BA" :
	set(value):
		syllable_text = value
		if is_inside_tree():
			$Label.text = syllable_text

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var home_position: Vector2 = Vector2.ZERO

@onready var label: Label = $Label
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var background: NinePatchRect = $Background

func _ready() -> void:
	$Label.text = syllable_text
	home_position = global_position
	
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _process(delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset

func _input(event: InputEvent) -> void:
	# Garante que ele perceba que soltamos o mouse mesmo fora da tela ou da área do objeto
	if is_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed: # Soltou o clique
			is_dragging = false
			z_index = 0
			
			var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
			
			syllable_dropped.emit(self)

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# Só captura o clique inicial (pressed = true)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not is_dragging:
			is_dragging = true
			drag_offset = get_global_mouse_position() - global_position
			z_index = 10
			
			var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
			
			syllable_grabbed.emit(self)

func _on_mouse_entered() -> void:
	if is_dragging:
		return
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.15)
	background.modulate = Color(1.25, 1.15, 1.0)

func _on_mouse_exited() -> void:
	if is_dragging:
		return
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	background.modulate = Color(1.0, 1.0, 1.0)

# Animação bonita caso o bloco precise voltar pra posição original dele (erro de sílaba ou drop fora)
func return_to_home() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", home_position, 0.4)
