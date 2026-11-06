class_name WindSwordSlashVfx
extends Node3D
## DONE: cung nguyên tố đủ làm vệt chính; burst nghe hit thật và dùng pool có trần.
## NOT DONE: chưa duyệt mỹ thuật trong toàn map hoặc kiểm tra export/cold cache.
## NOTES: không thay gameplay; cache mesh, không đèn, idle tắt process.
const SHADER: Shader = preload("res://abilities/fusion/wind/vfx/slash/wind_sword_slash.gdshader")
const HIT_SCENE: PackedScene = preload("res://abilities/fusion/wind/vfx/impact/melee/wind_sword_hit_vfx.tscn")
## Nạp kiểu trực tiếp để editor chưa cập nhật class_name vẫn parse được controller.
const HIT_VFX_SCRIPT = preload("res://abilities/fusion/wind/vfx/impact/melee/wind_sword_hit_vfx.gd")
const ELEMENT_ID: StringName = &"wind"
@export_group("Wiring")
@export var player: Player
@export_group("Shape")
@export_range(1, 8, 1) var strand_count: int = 3
@export_range(12, 96, 1) var segments: int = 56
@export_range(0.0, 1.0) var reach_ratio: float = 0.98
@export_range(0.0, 0.98) var inner_ratio: float = 0.22
@export var arc_degrees: float = 175.0
@export var height: float = 0.65
@export var depth: float = 0.10
@export var curl_amount: float = 0.20
@export var curl_speed: float = 8
@export var curl_turns: float = 0.8
@export var secondary_width: float = 0.065
@export var leading_weight: float = 0.35
@export var taper_power: float = 0.6
@export var edge_width: float = 0.06
@export var erode_scale: Vector2 = Vector2(12.0, 4.0)
@export var erode_sharpness: float = 0.018
@export var combo_height: Vector3 = Vector3(0.0, 0.06, 0.1)
@export var combo_curl: Vector3 = Vector3(0.8, 1.1, 1.35)
@export_group("Timing")
@export var appear_time: float = 0.012
@export var fade_time: float = 0.12
@export var flash_duration: float = 0.035
@export var flash_size: float = 0.30
@export var minimum_duration: float = 0.001
@export var prepare_on_ready: bool = true
@export_range(1, 6, 1) var prepare_frames: int = 3
@export var prepare_scale: float = 0.000001
@export var prepare_opacity: float = 0.000001
@export_group("Debris")
@export_range(0, 24, 1) var dust_count: int = 6
@export var dust_size: float = 0.065
@export var dust_drift: float = 0.15
@export_group("Hit Burst")
@export_range(1, 8, 1) var hit_pool_size: int = 4
@export var hit_duration: float = 0.18
@export var hit_size: float = 0.32
@export_group("Palette")
@export var core_color: Color = Color("c7f2ff")
@export var hot_color: Color = Color("e8fcff")
@export var body_color: Color = Color("58b6c4")
@export var edge_color: Color = Color("224952")
@export var noise_texture: Texture2D = preload("res://abilities/fusion/wind/vfx/textures/wind_noise.png")
static var _mesh_cache: Dictionary[Vector3i, ArrayMesh] = {}
var _material: ShaderMaterial
var _pool: ObjectPool
var _age: float = 0.0
var _active_time: float = 0.0
var _release: float = 0.0
var _armed: bool = false
var _direction: Vector3 = Vector3.FORWARD
var _reach: float = 1.65
var _clip_box: bool = false
var _box_center: Vector3 = Vector3.ZERO
var _box_size: Vector3 = Vector3.ONE
var _epoch: int = 0
@onready var _ribbons: MeshInstance3D = $Ribbons

## Tắt process trước await; child phải đợi Player gán các @onready của nó.
func _ready() -> void:
	top_level = true
	set_process(false)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_ribbons.material_override = _material
	_ribbons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ribbons.hide()

	_build_mesh()
	_configure()
	_pool = ObjectPool.new()
	_pool.name = "HitBursts"
	_pool.scene = HIT_SCENE
	_pool.initial_size = hit_pool_size
	_pool.configure_instance = _configure_hit
	add_child(_pool)
	if is_instance_valid(player) and not player.is_node_ready():
		await player.ready
	if is_instance_valid(player):
		_reach = player.hitbox.get_reach()
		player.fusion_melee_swing.connect(_on_swing)
		player.hitbox.hit.connect(_on_hit)
		player.hitbox.deactivated.connect(_on_deactivated)
		player.hitbox.cancelled.connect(_on_cancelled)
	_ribbons.custom_aabb = AABB(-Vector3.ONE * _reach, Vector3.ONE * _reach * 2.0)
	if prepare_on_ready and DisplayServer.get_name() != "headless":
		_prepare()

## Nét bám thân, chỉ xói hình sau active; không có vận tốc phóng ra trước.
func _process(delta: float) -> void:
	if not is_instance_valid(player):
		reset()
		return
	_age += delta
	global_position = player.global_position
	if _age >= _active_time:
		_armed = false
	if _age >= _active_time + _release:
		_ribbons.hide()
		set_process(false)
		return
	_material.set_shader_parameter(&"clock", _age)
	_material.set_shader_parameter(&"progress", clampf(_age / _active_time, 0.0, 1.0))
	_material.set_shader_parameter(&"dissolve", clampf((_age - _active_time) / _release, 0.0, 1.0))
	_material.set_shader_parameter(&"opacity", smoothstep(0.0, maxf(appear_time, minimum_duration), _age))

## Người dùng hoặc fixture dừng lượt phải trả cả các burst còn sống.
func reset() -> void:
	_epoch += 1
	_armed = false
	_ribbons.hide()
	set_process(false)
	if is_instance_valid(_pool): _pool.release_all()

## API kiểm tra trạng thái, không quét cây mỗi frame.
func is_visual_idle() -> bool:
	return not is_processing() and not _ribbons.visible and _pool.get_active_count() == 0

## Pool cố định, thiếu slot thì tái dùng slot cũ thay vì tăng số node giữa combat.
func get_hit_pool() -> ObjectPool:
	return _pool

## Hook giữ nguyên chữ ký; tầm dựa hitbox, không nhân scale làm vượt vùng đánh.
func _on_swing(element_id: StringName, attack: AttackData, combo_index: int, combo_size: int, direction: Vector3, active_time: float) -> void:
	if element_id != ELEMENT_ID or not is_instance_valid(player) or direction.is_zero_approx() or combo_size <= 0:
		return
	_epoch += 1
	_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_age = 0.0
	_active_time = maxf(active_time, minimum_duration)
	_release = maxf(fade_time, minimum_duration)
	_reach = maxf(player.hitbox.get_reach(), minimum_duration)
	_armed = true
	_clip_box = false
	global_transform = Transform3D(Basis.looking_at(-_direction), player.global_position)
	var index: int = posmod(combo_index, 3)
	var sweep: float = -1.0 if combo_index % 2 == 0 else 1.0
	var lift: float = height + combo_height[index]
	var tilt: float = 0.0
	if attack != null and attack.slash_style != null:
		lift += attack.slash_style.height_offset
		tilt = deg_to_rad(attack.slash_style.tilt_degrees)
	_material.set_shader_parameter(&"arc_radians", deg_to_rad(arc_degrees))
	_material.set_shader_parameter(&"body_gain", 1.0)
	_material.set_shader_parameter(&"heat_gain", 0.0)

	_material.set_shader_parameter(&"reach", _reach)
	_material.set_shader_parameter(&"sweep_sign", sweep)
	_material.set_shader_parameter(&"height", lift)
	_material.set_shader_parameter(&"tilt", tilt)
	_material.set_shader_parameter(&"curl", curl_amount * combo_curl[index])
	_material.set_shader_parameter(&"clip_box", _clip_box)
	_material.set_shader_parameter(&"box_center", _box_center)
	_material.set_shader_parameter(&"box_size", _box_size)
	_material.set_shader_parameter(&"clock", 0.0)
	_material.set_shader_parameter(&"progress", 0.0)
	_material.set_shader_parameter(&"dissolve", 0.0)
	_material.set_shader_parameter(&"opacity", 0.0)
	_material.set_shader_parameter(&"warm_scale", 1.0)
	_ribbons.show()
	set_process(true)

## Chỉ ghi nhận hit trong active của family đúng; không thay receive_hit hay sát thương.
func _on_hit(target: HurtboxComponent) -> void:
	if not _armed or not is_instance_valid(target) or not player.hitbox.is_active():
		return
	var fusion: FusionData = player.get_fusion()
	if fusion == null or fusion.element == null or fusion.element.id != ELEMENT_ID: return
	if _pool.get_active_count() >= hit_pool_size:
		_pool.release(_pool.get_oldest_active())
	var burst: HIT_VFX_SCRIPT = _pool.acquire() as HIT_VFX_SCRIPT
	var point: Vector3 = HIT_VFX_SCRIPT.surface_point(target, player.global_position + Vector3.UP * height)
	burst.play_at(point, _direction, player.global_position, _reach, hit_size, hit_duration, _clip_box, _box_center, _box_size)

## Hitbox bị ngắt phải dừng quyền phát burst ngay, không chờ đuôi VFX.
func _on_deactivated() -> void:
	_armed = false

## Mỗi slot nối trả pool đúng một lần lúc tạo sẵn.
func _configure_hit(node: Node) -> void:
	node.connect(&"finished", _pool.release.bind(node))

## Tài nguyên hình ảnh riêng instance chỉ giữ uniform thời gian; mesh/texture/shader dùng chung.
func _configure() -> void:
	for key: StringName in [&"reach_ratio", &"inner_ratio", &"depth", &"curl_speed", &"curl_turns", &"secondary_width", &"leading_weight", &"taper_power", &"edge_width", &"erode_scale", &"erode_sharpness", &"flash_duration", &"flash_size", &"dust_size", &"dust_drift", &"noise_texture", &"core_color", &"hot_color", &"body_color", &"edge_color"]:
		_material.set_shader_parameter(key, get(key))
	_material.set_shader_parameter(&"strand_count", float(strand_count))


## Một surface chứa cung, đuôi cong, hạt hình học và snap để giữ số draw nhỏ.
func _build_mesh() -> void:
	var key: Vector3i = Vector3i(strand_count, segments, dust_count)
	if _mesh_cache.has(key):
		_ribbons.mesh = _mesh_cache[key]
		return
	var vertices: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var uv2: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for layer: int in range(1 + strand_count + dust_count + 1):
		var kind: float = 0.0 if layer <= strand_count else (2.0 if layer == strand_count + dust_count + 1 else 1.0)
		var count: int = segments if kind == 0.0 else 1
		var base: int = vertices.size()
		for index: int in range(count + 1):
			for side: int in range(2):
				vertices.append(Vector3.ZERO)
				uv.append(Vector2(float(index) / float(count), float(side)))
				uv2.append(Vector2(float(layer), kind))
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
	_ribbons.mesh = mesh

## Shader nhận alpha dưới ngưỡng một mức màu 8-bit; vẫn chạy đúng render pass của camera game.
func _prepare() -> void:
	var epoch: int = _epoch
	_material.set_shader_parameter(&"reach", _reach)
	_material.set_shader_parameter(&"warm_scale", 1.0)
	_material.set_shader_parameter(&"opacity", prepare_opacity)
	_material.set_shader_parameter(&"progress", 0.65)
	_material.set_shader_parameter(&"clock", flash_duration * 0.5)
	_ribbons.show()
	for frame: int in range(prepare_frames):
		await RenderingServer.frame_post_draw
	if epoch == _epoch:
		_ribbons.hide()
		_material.set_shader_parameter(&"opacity", 0.0)
	print("SWORD_SHADER_PREP main ", ELEMENT_ID, " root_pass opacity=", prepare_opacity)

## Đòn bị hủy (dash, kỹ năng): xoá nét chém ngay. Giữ burst trúng đòn đang chạy: đó là phản hồi của cú đã trúng
func _on_cancelled() -> void:
	_epoch += 1
	_armed = false
	_ribbons.hide()
	set_process(false)
