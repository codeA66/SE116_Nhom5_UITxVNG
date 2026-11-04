class_name FireSwordHitVfx
extends Node3D
## DONE: burst nhỏ dùng lại từ pool; giới hạn theo snapshot tầm kiếm khi va chạm.
## NOT DONE: chưa kiểm tra export; điểm bề mặt là ước lượng hình ảnh, không phải contact point vật lý.
## NOTES: hạt là mảnh hình học trong một mesh chung, không đèn và không node phát sinh.
signal finished
const SHADER: Shader = preload("res://assets/vfx/fire/fire_sword/impact/fire_sword_hit_vfx.gdshader")
@export_group("Shape")
@export_range(1, 8, 1) var streak_count: int = 3
@export_range(0, 16, 1) var bits: int = 8
@export_range(8, 32, 1) var segments: int = 16
@export var spread: float = 0.75
@export var forward_push: float = 0.35
@export var edge_width: float = 0.12
@export_group("Palette")
@export var core_color: Color = Color("fff3b0")
@export var body_color: Color = Color("ff891e")
@export var edge_color: Color = Color("8c2513")
@export_group("Timing")
@export var minimum_duration: float = 0.001
@export var prepare_scale: float = 0.000001
@export var prepare_opacity: float = 0.000001
@export var prepare_frames: int = 3
static var _mesh_cache: Dictionary[Vector3i, ArrayMesh] = {}
static var _warmup_done: bool = false
static var _warmup_running: bool = false
var _material: ShaderMaterial
var _epoch: int = 0
var _age: float = 0.0
var _duration: float = 0.18
@onready var _mesh: MeshInstance3D = $Burst

## Mỗi slot có uniform riêng; hình học cùng cấu hình được cache chung.
func _ready() -> void:
	top_level = true
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build()
	for key: StringName in [&"spread", &"forward_push", &"edge_width", &"core_color", &"body_color", &"edge_color"]:
		_material.set_shader_parameter(key, get(key))
	pool_released()
	_prepare.call_deferred()

## Hết burst tự báo pool; không gọi queue_free khi đang combat.
func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		set_process(false)
		finished.emit()
		return
	_material.set_shader_parameter(&"progress", _age / _duration)

## Snapshot giới hạn độc lập player, tránh burst chạy theo người sau va chạm.
func play_at(point: Vector3, direction: Vector3, player_origin: Vector3, reach: float, size: float, duration: float, clip_box: bool, box_center: Vector3, box_size: Vector3) -> void:
	_epoch += 1
	global_transform = Transform3D(Basis.looking_at(-direction), point)
	_duration = maxf(duration, minimum_duration)
	_age = 0.0
	_material.set_shader_parameter(&"progress", 0.0)
	_material.set_shader_parameter(&"opacity", 1.0)
	_material.set_shader_parameter(&"size", size)
	_material.set_shader_parameter(&"warm_scale", 1.0)
	_material.set_shader_parameter(&"reach", reach)
	var offset: Vector3 = to_local(player_origin)
	_material.set_shader_parameter(&"limit_center", offset)
	_material.set_shader_parameter(&"clip_box", clip_box)
	_material.set_shader_parameter(&"box_center", offset + box_center)
	_material.set_shader_parameter(&"box_size", box_size)
	_mesh.custom_aabb = AABB(-Vector3.ONE * reach * 2.0, Vector3.ONE * reach * 4.0)
	_mesh.show()
	show()
	set_process(true)

## Pool nhả slot phải dừng cả process lẫn hình dù bị tái dùng sớm.
func pool_released() -> void:
	_epoch += 1
	set_process(false)
	if is_instance_valid(_mesh): _mesh.hide()
	hide()

## Điểm bề mặt gần phía kiếm là ước lượng VFX; Area hit không cung cấp contact point vật lý.
static func surface_point(target: HurtboxComponent, source: Vector3) -> Vector3:
	var shape_node: CollisionShape3D = target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null: return target.global_position
	var local: Vector3 = shape_node.to_local(source)
	var shape: Shape3D = shape_node.shape
	if shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = shape as CapsuleShape3D
		var axis: Vector3 = Vector3(0.0, clampf(local.y, -capsule.height * 0.5 + capsule.radius, capsule.height * 0.5 - capsule.radius), 0.0)
		var normal: Vector3 = (local - axis).normalized()
		return shape_node.to_global(axis + normal * capsule.radius)
	if shape is SphereShape3D:
		return shape_node.to_global(local.normalized() * (shape as SphereShape3D).radius)
	if shape is BoxShape3D:
		var half: Vector3 = (shape as BoxShape3D).size * 0.5
		return shape_node.to_global(local.clamp(-half, half))
	return shape_node.global_position

## Tessellation giữ sẵn nên phát lại chỉ đổi scalar.
func _build() -> void:
	var key: Vector3i = Vector3i(streak_count, bits, segments)
	if _mesh_cache.has(key):
		_mesh.mesh = _mesh_cache[key]
		return
	var vertices: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var uv2: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for layer: int in range(streak_count + bits):
		var count: int = segments if layer < streak_count else 1
		var base: int = vertices.size()
		for index: int in range(count + 1):
			for side: int in range(2):
				vertices.append(Vector3.ZERO)
				uv.append(Vector2(float(index) / float(count), float(side)))
				uv2.append(Vector2(float(layer), 0.0 if layer < streak_count else 1.0))
		for index: int in range(count):
			var a: int = base + index * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[key] = mesh
	_mesh.mesh = mesh

## Chỉ một slot chuẩn bị shader trong camera thật; alpha nhỏ do chính shader xử lý.
func _prepare() -> void:
	if _warmup_done or _warmup_running or DisplayServer.get_name() == "headless": return
	_warmup_running = true
	var epoch: int = _epoch
	_material.set_shader_parameter(&"warm_scale", 1.0)
	_material.set_shader_parameter(&"opacity", prepare_opacity)
	_material.set_shader_parameter(&"progress", 0.25)
	_mesh.custom_aabb = AABB(-Vector3.ONE * 4.0, Vector3.ONE * 8.0)
	_mesh.show()
	show()
	for frame: int in range(prepare_frames):
		await RenderingServer.frame_post_draw
	if epoch == _epoch:
		pool_released()
		_material.set_shader_parameter(&"opacity", 1.0)
	_warmup_done = true
	_warmup_running = false
	print("SWORD_SHADER_PREP burst root_pass opacity=", prepare_opacity)
