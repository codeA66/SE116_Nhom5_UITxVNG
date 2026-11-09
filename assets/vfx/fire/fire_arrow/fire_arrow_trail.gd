class_name FireArrowTrail
extends Node3D
## Vệt lửa bám theo mũi tên Cung Lửa lúc bay: quả lửa ở đầu tên + dải lửa dài dần phía sau (một mesh, một shader)
## + vài tàn lửa (Flames). Tên kết thúc (trúng / hết tầm) thì dải co về chỗ dừng, tàn đang bay tàn hết,
## rồi phát finished để trả về object pool.
## Biết tên kết thúc nhờ signal (finished của ArrowProjectile dùng pool, hoặc tree_exiting), không dò mỗi frame;
## _process chỉ để bám transform tên trong lúc bay và chạy phần tắt dần.

## Hết lượt: pool nối signal này để nhả node về
signal finished

const SHADER: Shader = preload("res://assets/vfx/fire/fire_arrow/fire_arrow_trail.gdshader")
## ArrowProjectile phát impacted lùi chừng này khỏi điểm trúng
const IMPACT_BACKOFF := 0.3

@export_group("Shape")
## Dải lửa dài tối đa (m); dài dần theo quãng tên đã bay
@export var max_length: float = 2.2
@export var trail_width: float = 0.5
@export var head_size: float = 0.42
## Quả lửa lùi sau đầu node tên bấy nhiêu mét (đầu tên nhô ra trước lửa)
@export var head_back: float = 0.12
@export_range(4, 32, 1) var segments: int = 12
@export var flicker_speed: float = 22.0
@export var wobble: float = 0.05
@export_group("Palette")
@export var core_color: Color = Color("fff3b0")
@export var body_color: Color = Color("ff891e")
## Viền đậm để lửa đọc được trên sàn sáng
@export var edge_color: Color = Color("8c2513")
@export_group("Timing")
## Dải co về và mờ hết sau khi tên dừng (s)
@export var fade_time: float = 0.14

static var _mesh_cache: Dictionary[int, ArrayMesh] = {}

var _projectile: Node3D
var _start: Vector3
var _length: float = 0.0
var _fade_left: float = 0.0
var _linger: float = 0.0
var _material: ShaderMaterial

@onready var _flames: GPUParticles3D = $Flames
@onready var _ribbon: MeshInstance3D = $Ribbon


## Đặt theo toạ độ thế giới (pool nằm dưới player), mặc định nghỉ
func _ready() -> void:
	top_level = true
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_ribbon.material_override = _material
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ribbon.mesh = _get_mesh(segments)
	for key: StringName in [&"trail_width", &"head_size", &"head_back", &"flicker_speed", &"wobble",
			&"core_color", &"body_color", &"edge_color"]:
		_material.set_shader_parameter(key, get(key))
	# Khung bao đủ cho cả dải dài nhất, tránh bị cắt khi tên bay ra rìa màn
	var extent := max_length + head_size + trail_width
	_ribbon.custom_aabb = AABB(-Vector3.ONE * extent, Vector3.ONE * extent * 2.0)
	_ribbon.hide()
	set_process(false)
	_flames.emitting = false


## Đang bay: bám tên, dải dài dần. Sau khi tên dừng: dải co về, rồi chờ tàn lửa tắt hẳn mới trả pool
func _process(delta: float) -> void:
	if _projectile:
		global_transform = _projectile.global_transform
		_set_length(minf(_start.distance_to(global_position), max_length))
		return
	if _fade_left > 0.0:
		_fade_left -= delta
		var t := clampf(_fade_left / maxf(fade_time, 0.001), 0.0, 1.0)
		_set_length(_length * t)
		_material.set_shader_parameter(&"intensity", t)
		if _fade_left <= 0.0:
			_ribbon.hide()
	_linger -= delta
	if _linger <= 0.0 and _fade_left <= 0.0:
		set_process(false)
		finished.emit()


## Gắn vệt lửa vào một mũi tên vừa bắn
func start(projectile: Node3D) -> void:
	_disconnect_projectile()
	_projectile = projectile
	_linger = 0.0
	_fade_left = 0.0
	_start = projectile.global_position
	global_transform = projectile.global_transform
	if projectile is ArrowProjectile:
		(projectile as ArrowProjectile).set_default_visual_enabled(false)
	projectile.tree_exiting.connect(_on_flight_ended, CONNECT_ONE_SHOT)
	# Tên dùng pool không rời cây khi kết thúc, nên nghe cả signal thu hồi của nó
	if projectile.has_signal(&"finished"):
		projectile.connect(&"finished", _on_flight_ended, CONNECT_ONE_SHOT)
	# Tên dừng lại (trúng / hết tầm) phát impacted hoặc chuyển sang mờ: lửa tắt ngay lúc tên dừng, không đợi vệt gốc mờ xong
	if projectile.has_signal(&"impacted"):
		projectile.connect(&"impacted", _on_impacted, CONNECT_ONE_SHOT)
	_set_length(0.0)
	_material.set_shader_parameter(&"intensity", 1.0)
	_ribbon.show()
	_flames.restart()
	_flames.emitting = true
	set_process(true)


## Pool nhả về giữa chừng: tắt hẳn, gỡ signal còn nối
func pool_released() -> void:
	_disconnect_projectile()
	_projectile = null
	_fade_left = 0.0
	_flames.emitting = false
	_ribbon.hide()
	set_process(false)


func _set_length(length: float) -> void:
	_length = length
	_material.set_shader_parameter(&"trail_length", length)


## Tên báo trúng trước khi tự dời tới điểm trúng: đặt vệt ngay điểm trúng thật (impacted lùi 0.3 m khỏi điểm này)
func _on_impacted(hit_position: Vector3, direction: Vector3) -> void:
	_on_flight_ended()
	global_position = hit_position + direction * IMPACT_BACKOFF


## Tên kết thúc: thôi phát tàn, dải co về chỗ dừng.
## Tham số tuỳ chọn: ArrowProjectile.finished gửi kèm mũi tên, còn tree_exiting thì không gửi gì
func _on_flight_ended(_projectile_arg: Node = null) -> void:
	if _projectile == null:
		return
	global_transform = _projectile.global_transform
	_disconnect_projectile()
	_projectile = null
	_flames.emitting = false
	_fade_left = fade_time
	_linger = _flames.lifetime


## Gỡ signal đang nối với tên (tên dùng pool sẽ được bắn lại, không để nối thừa)
func _disconnect_projectile() -> void:
	if not is_instance_valid(_projectile):
		return
	if _projectile.tree_exiting.is_connected(_on_flight_ended):
		_projectile.tree_exiting.disconnect(_on_flight_ended)
	if _projectile.has_signal(&"finished") and _projectile.is_connected(&"finished", _on_flight_ended):
		_projectile.disconnect(&"finished", _on_flight_ended)
	if _projectile.has_signal(&"impacted") and _projectile.is_connected(&"impacted", _on_impacted):
		_projectile.disconnect(&"impacted", _on_impacted)


## Dải segments ô (UV2.y = 0) + một ô quả lửa đầu tên (UV2.y = 1); dựng một lần, các vệt dùng chung
static func _get_mesh(count: int) -> ArrayMesh:
	if _mesh_cache.has(count):
		return _mesh_cache[count]
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var indices := PackedInt32Array()
	for strip in 2:
		var cells := count if strip == 0 else 1
		var base := vertices.size()
		for index in cells + 1:
			for side in 2:
				vertices.append(Vector3.ZERO)
				uv.append(Vector2(float(index) / float(cells), float(side)))
				uv2.append(Vector2(0.0, float(strip)))
		for index in cells:
			var a := base + index * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[count] = mesh
	return mesh
