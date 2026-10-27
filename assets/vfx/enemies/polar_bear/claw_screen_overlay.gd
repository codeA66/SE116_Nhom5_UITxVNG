class_name ClawScreenOverlay
extends Node3D
## Vệt cào trên canvas bám điểm thế giới, giữ góc vẽ khi camera đổi hướng và không bị che.
const SHADER: Shader = preload("res://assets/vfx/enemies/polar_bear/claw_screen_overlay.gdshader")
@export var world_radius: float = 2.4
@export var center_height: float = 0.8
@export var duration: float = 1.1
var _rect: ColorRect
var _material: ShaderMaterial
var _active: bool = false

func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect.material = _material
	layer.add_child(_rect)
	seek(-1.0)

func seek(seconds: float) -> void:
	_active = seconds >= 0.0 and seconds < duration and is_visible_in_tree()
	_rect.visible = _active
	set_process(_active)
	_material.set_shader_parameter(&"age", seconds)
	_material.set_shader_parameter(&"duration", duration)
	if _active: _project()

func _process(_delta: float) -> void:
	_project()

func _project() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		_rect.hide(); return
	var center: Vector3 = global_position + Vector3.UP * center_height
	if camera.is_position_behind(center):
		_rect.hide(); return
	var screen: Vector2 = camera.unproject_position(center)
	var edge: Vector2 = camera.unproject_position(center + camera.global_basis.x * world_radius)
	var radius: float = maxf(edge.distance_to(screen), 1.0)
	_rect.size = Vector2.ONE * radius * 2.0
	_rect.position = screen - _rect.size * 0.5
	_rect.show()

func screen_rect() -> Rect2:
	return Rect2(_rect.position, _rect.size)

func overlay_visible() -> bool:
	return _rect.visible
