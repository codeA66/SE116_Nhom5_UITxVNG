class_name FireSwordVfx
extends Node3D
## DONE 2026-10-31: cung kiếm nghe hook generic; chỉ fire, không tạo sát thương hay vùng đốt.
## NOT DONE: chờ gắn scene vào Player thật; không thay thế FireTouch của nhát cuối.
## NOTES: dựng mesh một lần, không đèn, CPU tối đa 48 hạt, nghỉ hoàn toàn sau lượt.
@export_group("Wiring")
@export var player: Player
@export_group("Shape")
@export var fallback_reach: float = 1.65
@export var reach_ratio: float = 0.95
@export var finisher_scale: float = 1.35
@export var inner_ratio: float = 0.52
@export var height: float = 0.65
@export var arc_degrees: float = 175.0
@export_range(12, 96, 1) var segments: int = 56
@export var depth: float = 0.16
@export var tongue_size: float = 0.08
@export var tongue_count: float = 7.0
@export var echo_scale: float = 1.12
@export var default_tilt: float = 12.0
@export_group("Timing")
@export var min_sweep: float = 0.045
@export var max_sweep: float = 0.16
@export var hold_time: float = 0.045
@export var release_time: float = 0.20
@export var finisher_release: float = 0.30
@export var echo_delay: float = 0.035
@export var flash_duration: float = 0.045
@export var flash_size: float = 0.7
@export var flash_forward_ratio: float = 0.60
@export var ember_lifetime: float = 0.38
@export var prepare_on_ready: bool = true
@export var prepare_frames: int = 3
@export_group("Budget")
@export_range(1, 29, 1) var normal_particles: int = 20
@export_range(1, 59, 1) var finisher_particles: int = 48
@export_group("Palette")
@export var core_color: Color = Color("fff0ab")
@export var hot_color: Color = Color("ffc43d")
@export var flame_color: Color = Color("ff7a09")
@export var edge_color: Color = Color("b93612")
@export var curl_amount: float = 0.10
@export var flow_speed: float = 1.8
@export var edge_sharpness: float = 0.025
var _age: float = 0.0
var _sweep: float = 0.08
var _release: float = 0.2
var _duration: float = 0.0
var _finisher: bool = false
var _epoch: int = 0
var _points: PackedVector3Array = PackedVector3Array()
@onready var _flash: MeshInstance3D = $Flash
@onready var _flash_mat: ShaderMaterial = $Flash.material_override as ShaderMaterial
@onready var _arc: MeshInstance3D = $Arc
@onready var _echo: MeshInstance3D = $Echo
@onready var _embers: CPUParticles3D = $Embers
@onready var _mat: ShaderMaterial = $Arc.material_override as ShaderMaterial
var _echo_mat: ShaderMaterial

## Liên kết một lần; người dùng gắn scene ở Player root và gán player trong Inspector.
func _ready() -> void:
	top_level = true
	set_process(false)
	_build_arc()
	_echo_mat = _mat.duplicate() as ShaderMaterial
	_echo.material_override = _echo_mat
	for mat: ShaderMaterial in [_mat, _echo_mat, _flash_mat]:
		mat.set_shader_parameter(&"core_color", core_color)
		mat.set_shader_parameter(&"hot_color", hot_color)
		mat.set_shader_parameter(&"flame_color", flame_color)
		mat.set_shader_parameter(&"edge_color", edge_color)
		mat.set_shader_parameter(&"curl_amount", curl_amount)
		mat.set_shader_parameter(&"flow_speed", flow_speed)
		mat.set_shader_parameter(&"edge_sharpness", edge_sharpness)
	if is_instance_valid(player):
		if not player.fusion_melee_swing.is_connected(_on_swing):
			player.fusion_melee_swing.connect(_on_swing)
	if prepare_on_ready and DisplayServer.get_name() != "headless":
		await _prepare()

## Chỉ ghi scalar/material khi đang có lượt; không dựng mesh hoặc tạo node trong combat.
func _process(delta: float) -> void:
	_age += delta
	if _age >= flash_duration:
		_flash.hide()
	if is_instance_valid(player):
		global_position = player.global_position
	_animate(_mat, _age)
	if _finisher:
		_animate(_echo_mat, maxf(_age - echo_delay, 0.0))
	if _age >= _duration:
		reset()

## Chỉ hook fire được phát hình; nhát cuối lấy combo_size, không gắn cứng vào nhát thứ ba.
func _on_swing(element_id: StringName, attack: AttackData, combo_index: int, combo_size: int, direction: Vector3, active_time: float) -> void:
	if element_id != &"fire":
		return
	if not is_instance_valid(player) or combo_size <= 0:
		return
	_epoch += 1
	_age = 0.0
	_finisher = combo_index == combo_size - 1
	_sweep = clampf(active_time, min_sweep, max_sweep)
	_release = maxf(finisher_release if _finisher else release_time, 0.001)
	_duration = maxf(_sweep + hold_time + _release + (echo_delay if _finisher else 0.0), ember_lifetime)
	var facing: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if facing.is_zero_approx():
		return
	global_transform = Transform3D(Basis.looking_at(-facing, Vector3.UP), player.global_position)
	var weapon: WeaponData = player.get_weapon()
	var reach: float = maxf(weapon.attack_range if weapon else fallback_reach, 0.01) * reach_ratio
	var sweep_dir: float = -1.0 if combo_index % 2 else 1.0
	var tilt: float = default_tilt
	var lift: float = 0.0
	if attack and attack.slash_style:
		var style: SlashStyle = attack.slash_style
		sweep_dir = float(style.sweep_direction)
		tilt = style.tilt_degrees
		lift = style.height_offset
		reach *= style.trail_scale
	elif attack and attack.slash_trail_direction != 0:
		sweep_dir = float(attack.slash_trail_direction)
	reach *= finisher_scale if _finisher else 1.0
	_arc.scale = Vector3.ONE * reach
	_echo.scale = Vector3.ONE * reach * echo_scale
	_arc.position.y = height + lift
	_echo.position.y = height + lift + depth
	_arc.rotation.z = deg_to_rad(tilt) * sweep_dir
	_echo.rotation.z = -deg_to_rad(tilt) * sweep_dir
	_mat.set_shader_parameter(&"sweep_sign", sweep_dir)
	_echo_mat.set_shader_parameter(&"sweep_sign", sweep_dir)
	_mat.set_shader_parameter(&"prewarm_scale", 1.0)
	_echo_mat.set_shader_parameter(&"prewarm_scale", 1.0)
	_animate(_mat, 0.0)
	_animate(_echo_mat, 0.0)
	_flash.position = Vector3(0, height + lift, reach * flash_forward_ratio)
	_flash.scale = Vector3.ONE * flash_size
	_flash.visible = _finisher
	_arc.show()
	_echo.visible = _finisher
	_embers.emitting = false
	_embers.amount = clampi(finisher_particles, 1, 59) if _finisher else clampi(normal_particles, 1, 29)
	_embers.lifetime = maxf(ember_lifetime, 0.01)
	_embers.scale = Vector3.ONE * reach
	_embers.position.y = height + lift
	_embers.show()
	_embers.restart()
	_embers.emitting = true
	set_process(true)

## Pool hoặc hết lượt gọi cùng một đường dọn; không để hạt cũ xuất hiện lại ở lần sau.
func reset() -> void:
	_epoch += 1
	_flash.hide()
	_arc.hide()
	_echo.hide()
	_embers.emitting = false
	_embers.hide()
	_age = 0.0
	set_process(false)

## Quét nhanh, giữ ngắn, rồi xói mép; cung phụ lệch nhịp thay vì bật đồng loạt.
func _animate(mat: ShaderMaterial, age: float) -> void:
	mat.set_shader_parameter(&"clock", age)
	var t: float = clampf(age / maxf(_sweep, 0.001), 0.0, 1.0)
	mat.set_shader_parameter(&"reveal", 1.0 - pow(1.0 - t, 3.0))
	mat.set_shader_parameter(&"dissolve", clampf((age - _sweep - hold_time) / _release, 0.0, 1.0))

## Hai mặt cung cong tạo chiều sâu; mảng điểm hạt giữ sẵn và dùng lại.
func _build_arc() -> void:
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var count: int = clampi(segments, 12, 96)
	for layer: int in range(2):
		var base: int = vertices.size()
		for i: int in range(count + 1):
			var u: float = float(i) / count
			var angle: float = (u - 0.5) * deg_to_rad(arc_degrees)
			var envelope: float = pow(maxf(sin(u * PI), 0.0), 0.5)
			for side: int in range(2):
				var r: float = 1.0 - (1.0 - inner_ratio) * envelope * float(1 - side)
				r += pow(maxf(sin(u * TAU * tongue_count + sin(u * 11.0)), 0.0), 3.0) * tongue_size * envelope * side
				vertices.append(Vector3(sin(angle) * r, (float(side) - 0.5) * depth * layer * envelope, cos(angle) * r))
				uvs.append(Vector2(u, float(side)))
			if layer == 0 and i % 4 == 0:
				_points.append(Vector3(sin(angle), 0.0, cos(angle)))
		for i: int in range(count):
			var a: int = base + i * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_arc.mesh = mesh
	_echo.mesh = mesh
	_embers.emission_points = _points

## Shader vẫn được vẽ ở kích thước không thấy được; hook đến giữa warmup được ưu tiên.
func _prepare() -> void:
	var epoch: int = _epoch
	_mat.set_shader_parameter(&"prewarm_scale", 0.000001)
	_echo_mat.set_shader_parameter(&"prewarm_scale", 0.000001)
	_arc.show()
	_echo.show()
	_flash.scale = Vector3.ONE * 0.000001
	_flash.show()
	_embers.scale = Vector3.ONE * 0.000001
	_embers.show()
	_embers.restart()
	_embers.emitting = true
	for frame: int in range(prepare_frames):
		await RenderingServer.frame_post_draw
	if epoch != _epoch:
		return
	reset()
	_mat.set_shader_parameter(&"prewarm_scale", 1.0)
	_echo_mat.set_shader_parameter(&"prewarm_scale", 1.0)
