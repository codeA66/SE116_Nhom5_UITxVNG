class_name WindSwordWave
extends FusionMove
## Lưỡi liềm gió bay thẳng (số nhát chỉnh ở wave_count), cùng ngôn ngữ hình với vệt chém kiếm: thân tối, viền gió sáng.
## Kiếm + Gió phóng ra ở nhát cuối combo. Mỗi nhát xuyên quái (mỗi quái chỉ trúng một lần mỗi nhát), gây sát thương
## và đẩy lùi; chạm tường / vật cản thì tan. Trúng thì bung vài nét gió nhỏ (pool), không có lá cho đỡ rối mắt.
## Va chạm theo signal của Area3D; chỉ chạy _physics_process khi còn nhát đang bay hoặc hiệu ứng chưa tắt.

const TRAIL_SHADER: Shader = preload("res://assets/shaders/slash_trail.gdshader")
const GLOW_SHADER: Shader = preload("res://assets/shaders/slash_glow.gdshader")

@export_group("Waves")
@export_range(1, 10) var wave_count: int = 3
## Khoảng cách thời gian giữa hai nhát (s)
@export_range(0.0, 1.0, 0.01) var interval: float = 0.12
@export var speed: float = 16.0
## Quãng đường tối đa mỗi nhát (m)
@export var max_distance: float = 9.0
## Rộng x cao x dày của vùng trúng (m)
@export var wave_size: Vector3 = Vector3(2.4, 1.2, 0.6)
## Độ cao tâm nhát gió so với chân người tung (m)
@export var height: float = 0.9

@export_group("Collision")
## Thế giới (chặn) + hurtbox quái (trúng)
@export_flags_3d_physics var collision_mask: int = 5
@export_flags_3d_physics var world_mask: int = 1

@export_group("Look")
## Bán kính trong / ngoài của lưỡi liềm và độ mở cung (độ)
@export var inner_radius: float = 1.0
@export var outer_radius: float = 1.6
@export var arc_degrees: float = 120.0
@export var body_color: Color = Color(0.012, 0.018, 0.035)
@export var edge_color: Color = Color(0.45, 0.8, 1.0)
@export var edge_intensity: float = 2.6
## Lưỡi liềm bắt đầu tan khi bay được tỉ lệ này của quãng đường
@export_range(0.0, 1.0) var dissolve_from: float = 0.45
## Giữ node thêm bấy nhiêu giây sau nhát cuối để cú bung / bụi trúng chạy hết
@export var linger: float = 0.6

var _user: Character
var _attack: AttackData
var _direction: Vector3
var _spawned: int = 0
var _clock: float = 0.0
var _done_at: float = -1.0
## Mỗi phần tử: {area, travelled, hit, trail, glow}
var _waves: Array[Dictionary] = []
var _shape: BoxShape3D
var _arc_mesh: ArrayMesh

@onready var _impacts: WindImpactPool = $ImpactPool


func _ready() -> void:
	set_physics_process(false)


func perform(user: Character, attack: AttackData, direction: Vector3) -> void:
	_user = user
	_attack = attack
	_direction = direction.normalized()
	global_transform = Transform3D(Basis.looking_at(_direction, Vector3.UP), user.global_position + Vector3.UP * height)
	_shape = BoxShape3D.new()
	_shape.size = wave_size
	_arc_mesh = _build_arc_mesh()
	_spawn_wave()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_clock += delta
	while _spawned < wave_count and _clock >= interval * _spawned:
		_spawn_wave()
	var step := speed * delta
	for i in range(_waves.size() - 1, -1, -1):
		var wave: Dictionary = _waves[i]
		var area := wave.area as Area3D
		area.global_position += _direction * step
		wave.travelled += step
		var life := clampf(wave.travelled / max_distance, 0.0, 1.0)
		var dissolve := clampf((life - dissolve_from) / maxf(1.0 - dissolve_from, 0.001), 0.0, 1.0)
		for material: ShaderMaterial in [wave.trail, wave.glow]:
			material.set_shader_parameter(&"dissolve", dissolve * dissolve)
		if wave.travelled >= max_distance:
			_remove_wave(i)
	if _spawned >= wave_count and _waves.is_empty():
		if _done_at < 0.0:
			_done_at = _clock
		elif _clock - _done_at >= linger:
			queue_free()


func _spawn_wave() -> void:
	_spawned += 1
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = collision_mask
	area.monitorable = false
	var cs := CollisionShape3D.new()
	cs.shape = _shape
	area.add_child(cs)
	# Hai lớp như vệt chém kiếm: thân tối + lớp sáng cộng màu; material riêng mỗi nhát vì độ tan khác nhau
	var trail := _crescent_material(TRAIL_SHADER)
	trail.set_shader_parameter(&"body_color", body_color)
	var glow := _crescent_material(GLOW_SHADER)
	glow.set_shader_parameter(&"edge_color", edge_color)
	glow.set_shader_parameter(&"edge_intensity", edge_intensity)
	glow.set_shader_parameter(&"core_intensity", edge_intensity * 1.4)
	glow.set_shader_parameter(&"blade_intensity", edge_intensity * 0.75)
	for material: ShaderMaterial in [trail, glow]:
		var visual := MeshInstance3D.new()
		visual.mesh = _arc_mesh
		visual.material_override = material
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Lưỡi liềm nằm ngang, lùi về sau để mép cong phía trước trùng mặt trước vùng trúng
		visual.position = Vector3(0.0, 0.0, outer_radius - wave_size.z * 0.5)
		area.add_child(visual)
	add_child(area)
	area.global_transform = Transform3D(Basis.looking_at(_direction, Vector3.UP), global_position)
	var wave := {"area": area, "travelled": 0.0, "hit": [] as Array[HurtboxComponent], "trail": trail, "glow": glow}
	_waves.append(wave)
	area.area_entered.connect(_on_area_entered.bind(wave))
	area.body_entered.connect(_on_body_entered.bind(wave))


func _crescent_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"head", 1.0)
	material.set_shader_parameter(&"dissolve", 0.0)
	material.set_shader_parameter(&"direction", 1.0)
	material.set_shader_parameter(&"seed", float(_spawned) * 3.7)
	return material


## Cung lưỡi liềm nằm ngang, phình về phía trước (-Z). UV.x dọc cung, UV.y từ mép trong ra mép ngoài
## (đúng quy ước của slash_crescent.gdshaderinc)
func _build_arc_mesh() -> ArrayMesh:
	var count := 48
	var half := deg_to_rad(arc_degrees) * 0.5
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in count + 1:
		var u := float(i) / float(count)
		var angle := lerpf(-half, half, u)
		var dir := Vector3(sin(angle), 0.0, -cos(angle))
		vertices.append(dir * inner_radius)
		uvs.append(Vector2(u, 0.0))
		vertices.append(dir * outer_radius)
		uvs.append(Vector2(u, 1.0))
	for i in count:
		var a := i * 2
		indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _on_area_entered(other: Area3D, wave: Dictionary) -> void:
	var hurtbox := other as HurtboxComponent
	var hit: Array[HurtboxComponent] = wave.hit
	if hurtbox == null or hurtbox in hit or not hurtbox.is_alive():
		return
	if is_instance_valid(_user) and hurtbox.owner == _user:
		return
	hit.append(hurtbox)
	var source: Node = _user if is_instance_valid(_user) else null
	var info := DamageInfo.new(_attack.damage, _attack.damage_type, _direction * _attack.knockback, source)
	info.direction = _direction
	info.attack = _attack
	hurtbox.receive_hit(info)
	_impacts.play_at(hurtbox.global_position, _direction)


func _on_body_entered(body: Node3D, wave: Dictionary) -> void:
	# Chỉ vật cản thế giới làm tan nhát gió; thân quái (CharacterBody) đã xử lý qua hurtbox
	if body is CollisionObject3D and (body as CollisionObject3D).collision_layer & world_mask != 0 and not body is Character:
		var index := _waves.find(wave)
		if index >= 0:
			_impacts.play_at((wave.area as Area3D).global_position, _direction)
			_remove_wave(index)


func _remove_wave(index: int) -> void:
	(_waves[index].area as Area3D).queue_free()
	_waves.remove_at(index)
