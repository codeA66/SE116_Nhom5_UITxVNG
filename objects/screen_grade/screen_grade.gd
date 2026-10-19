class_name ScreenGrade
extends CanvasLayer
## Hậu kỳ màn hình của khu (chỉnh màu, vignette, vùng sáng quanh player). Vùng sáng bám theo vị trí
## player trên màn hình: nối signal ZoneRoot.player_spawned vào set_focus_target trong scene khu.
## Không có target thì vùng sáng nằm giữa màn hình và không chạy _process.

## Điểm sáng đặt ở ngang ngực player (m) để vùng sáng ôm cả người chứ không lệch xuống chân
@export var focus_height: float = 0.9

var _target: Node3D

@onready var _material: ShaderMaterial = $Grade.material as ShaderMaterial


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		set_process(false)
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var point := _target.global_position + Vector3.UP * focus_height
	if camera.is_position_behind(point):
		return
	var screen := camera.unproject_position(point) / get_viewport().get_visible_rect().size
	_material.set_shader_parameter(&"focus_uv", screen)


func set_focus_target(target: Node3D) -> void:
	_target = target
	set_process(is_instance_valid(_target))
