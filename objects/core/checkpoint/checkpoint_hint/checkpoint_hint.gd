extends Node3D
## Trỏ vào miếu và phản hồi khi Foxy bước vào vùng hồi phục.

const THEME: Theme = preload("res://ui/theme/menu_theme.tres")

@export_group("Vòng sáng")
@export_range(0.1, 3.0, 0.01) var pulse_time: float = 0.85

var _pulse: Tween

@onready var _ring: MeshInstance3D = $Ring
@onready var _ring_material: ShaderMaterial = _ring.material_override as ShaderMaterial


func _ready() -> void:
	var title: Label3D = $Title
	title.font = THEME.default_font
	var trigger: Area3D = get_node(^"../Trigger")
	trigger.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return
	if _pulse != null:
		_pulse.kill()
	_ring.show()
	_ring_material.set_shader_parameter(&"progress", 0.0)
	_pulse = create_tween()
	_pulse.tween_property(_ring_material, ^"shader_parameter/progress", 1.0, pulse_time)
	_pulse.tween_callback(_ring.hide)
