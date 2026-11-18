class_name BossHitFeedback
extends Node
## Cache mesh thân boss, dùng lại Timer để không tạo Tween ở mỗi hit.

@export var body_root: Node3D
@export var hurtbox: HurtboxComponent
@export var hit_flash_color: Color = Color(1.0, 0.15, 0.15, 0.75)
@export var hit_flash_time: float = 0.12
@export var spark_height: float = 1.5

var _meshes: Array[GeometryInstance3D] = []
var _original_overlays: Array[Material] = []
var _material: StandardMaterial3D
var _combat_fx: Node

@onready var _timer: Timer = $FlashTimer


func _ready() -> void:
	_combat_fx = get_node_or_null(^"/root/CombatFx")
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for node: Node in body_root.find_children("*", "MeshInstance3D", true, false):
		var mesh: GeometryInstance3D = node as GeometryInstance3D
		_meshes.append(mesh)
		_original_overlays.append(mesh.material_overlay)
	_timer.timeout.connect(_clear_flash)
	hurtbox.hurt.connect(_on_hurt)


func _on_hurt(_info: DamageInfo, _damage: int) -> void:
	_material.albedo_color = hit_flash_color
	for mesh: GeometryInstance3D in _meshes:
		mesh.material_overlay = _material
	_timer.start(maxf(hit_flash_time, 0.001))
	if _combat_fx and _combat_fx.has_method(&"spawn_hit"):
		_combat_fx.call(&"spawn_hit", body_root.global_position + Vector3.UP * spark_height, Vector3.UP)


func _clear_flash() -> void:
	for index: int in _meshes.size():
		_meshes[index].material_overlay = _original_overlays[index]
