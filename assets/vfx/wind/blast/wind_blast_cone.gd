class_name WindBlastCone
extends Node3D
## Hình ảnh cú thổi gió (Wind Blast): một cơn lốc xoáy hình phễu hình thành ở tay player lúc gồng,
## rồi lao về phía trước tới hết tầm thổi (WindBlastData.reach) và tan ra. Chỉ nghe signal của WindBlastArea,
## không chứa logic đẩy. Đặt dưới gốc Player (không dưới Model: foxy_player.gd ghi đè material mọi mesh dưới Model).
## Lốc tự xoay trên GPU (shader); script chỉ chạy _process trong lúc hiệu ứng đang diễn ra.

signal charge_finished
signal blast_finished

enum Phase { IDLE, CHARGE, TRAVEL, DISSOLVE }

## Tránh chia cho 0 khi các thời gian bị chỉnh về 0
const MIN_TIME := 0.001

@export var area: WindBlastArea

@export_group("Shape")
## Chiều cao lốc (m) khi WindBlastData.height = 2; tỉ lệ theo height
@export var funnel_height: float = 3.6
## Bán kính đáy và đỉnh phễu (m) khi WindBlastData.width = 2.5; tỉ lệ theo width
@export var base_radius: float = 0.24
@export var top_radius: float = 1.6
## Độ cong của phễu: > 1 thì loe mạnh ở phần trên
@export var flare: float = 1.6
@export_range(1, 16) var ribbon_count: int = 5
## Số vòng xoắn mỗi dải đi quanh trục
@export var ribbon_turns: float = 1.25
## Phần chiều cao mỗi dải chiếm (0..1)
@export_range(0.05, 1.0) var ribbon_span: float = 0.62
## Bề ngang dải (m)
@export var ribbon_width: float = 0.42
@export_range(8, 64) var ribbon_segments: int = 40
## Số cạnh quanh trục của thân phễu mờ
@export_range(6, 48) var shell_sides: int = 20
@export var random_seed: int = 11

@export_group("Timing")
## Lốc lao tới hết tầm trong khoảng này (s)
@export var travel_time: float = 0.32
## Tan ra sau khi tới nơi (s)
@export var dissolve_time: float = 0.22
## Kích thước lốc lúc gồng ở tay so với lúc bay
@export_range(0.05, 1.0) var charge_scale: float = 0.35
## Lốc to thêm lúc tan (tỉ lệ)
@export var dissolve_growth: float = 0.35

@export_group("Look")
@export var core_color: Color = Color(1.0, 1.0, 1.0)
@export var edge_color: Color = Color(0.07, 0.27, 0.45)
@export var core_intensity: float = 1.8
@export var spin_speed: float = 2.6
## Cao độ đáy lốc so với chân player (m)
@export var ground_lift: float = 0.03
## Dò đất dưới lốc: không có đất (đang trên không, trên vực) thì ẩn vòng bụi
@export var ground_check_distance: float = 1.6
@export_flags_3d_physics var ground_mask: int = 1

var _phase: Phase = Phase.IDLE
var _time: float = 0.0
var _charge_time: float = 0.12
var _origin: Vector3
var _forward: Vector3 = Vector3.BACK
var _reach: float = 5.0
var _size: Vector3 = Vector3.ONE
var _ground_query: PhysicsRayQueryParameters3D

@onready var _funnel: MeshInstance3D = $Funnel
@onready var _ground: MeshInstance3D = $Ground
@onready var _sparkles: CPUParticles3D = $Sparkles
@onready var _shell: MeshInstance3D = $Shell
@onready var _shell_material: ShaderMaterial = _shell.material_override as ShaderMaterial
@onready var _funnel_material: ShaderMaterial = _funnel.material_override as ShaderMaterial
@onready var _ground_material: ShaderMaterial = _ground.material_override as ShaderMaterial


func _ready() -> void:
	top_level = true
	visible = false
	set_process(false)
	_ground_query = PhysicsRayQueryParameters3D.new()
	_ground_query.collision_mask = ground_mask
	_funnel.mesh = _build_funnel_mesh()
	_shell.mesh = _build_shell_mesh()
	_apply_look()
	if area == null:
		push_error("%s: chưa gán WindBlastArea" % get_path())
		return
	area.charge_started.connect(_on_charge_started)
	area.blast_started.connect(_on_blast_started)
	area.blast_stopped.connect(_on_blast_stopped)


func _process(delta: float) -> void:
	_time += delta
	match _phase:
		Phase.CHARGE:
			_update_charge()
		Phase.TRAVEL:
			_update_travel()
		Phase.DISSOLVE:
			_update_dissolve()


func is_charging() -> bool:
	return _phase == Phase.CHARGE


## Lốc đang bay hoặc đang tan
func is_playing() -> bool:
	return _phase == Phase.TRAVEL or _phase == Phase.DISSOLVE


## Tổng thời gian một cú bung (bay + tan)
func get_blast_time() -> float:
	return travel_time + dissolve_time


# ---------- Signal ----------

func _on_charge_started(data: WindBlastData) -> void:
	_read_data(data)
	_charge_time = maxf(data.active_start, MIN_TIME)
	_enter(Phase.CHARGE)
	visible = true
	_ground.visible = false
	_sparkles.emitting = false
	_set_dissolve(0.0)
	_update_charge()


func _on_blast_started(data: WindBlastData) -> void:
	_read_data(data)
	if _phase != Phase.CHARGE:
		visible = true
	charge_finished.emit()
	_enter(Phase.TRAVEL)
	_ground.visible = _has_ground_below(_origin)
	_sparkles.restart()
	_sparkles.emitting = true
	_update_travel()


## Phát cả khi hết khoảng thổi lẫn khi rời state: chỉ huỷ nếu bị ngắt lúc còn đang gồng
func _on_blast_stopped() -> void:
	if _phase == Phase.CHARGE:
		_finish()


# ---------- Pha ----------

func _enter(phase: Phase) -> void:
	_phase = phase
	_time = 0.0
	set_process(true)


func _update_charge() -> void:
	var k := clampf(_time / _charge_time, 0.0, 1.0)
	_follow_area()
	global_position = _origin
	scale = _size * lerpf(charge_scale * 0.4, charge_scale, _ease_out(k))
	_funnel_material.set_shader_parameter(&"grow", lerpf(0.3, 1.0, k))


func _update_travel() -> void:
	var k := clampf(_time / maxf(travel_time, MIN_TIME), 0.0, 1.0)
	var eased := _ease_out(k)
	global_position = _origin + _forward * _reach * eased
	scale = _size * lerpf(charge_scale, 1.0, minf(k * 2.5, 1.0))
	_funnel_material.set_shader_parameter(&"grow", 1.0)
	_ground_material.set_shader_parameter(&"spread", lerpf(0.25, 0.75, eased))
	if k >= 1.0:
		_enter(Phase.DISSOLVE)


func _update_dissolve() -> void:
	var k := clampf(_time / maxf(dissolve_time, MIN_TIME), 0.0, 1.0)
	var eased := _ease_in(k)
	scale = _size * (1.0 + dissolve_growth * _ease_out(k))
	_set_dissolve(eased)
	_ground_material.set_shader_parameter(&"spread", lerpf(0.75, 0.95, _ease_out(k)))
	if k >= 1.0:
		_finish()


func _finish() -> void:
	var was_blasting := _phase != Phase.CHARGE
	_phase = Phase.IDLE
	visible = false
	_sparkles.emitting = false
	set_process(false)
	if was_blasting:
		blast_finished.emit()
	else:
		charge_finished.emit()


# ---------- Tiện ích ----------

## Lấy hướng, gốc và kích thước từ vùng thổi thật để hình luôn khớp vùng đẩy
func _read_data(data: WindBlastData) -> void:
	_reach = maxf(data.reach, 0.0)
	_size = Vector3(data.width / 2.5, data.height / 2.0, data.width / 2.5).max(Vector3.ONE * 0.05)
	_follow_area()


func _follow_area() -> void:
	if area == null:
		return
	var forward := area.global_basis.z
	forward.y = 0.0
	_forward = forward.normalized() if not forward.is_zero_approx() else Vector3.BACK
	_origin = area.global_position + Vector3.UP * ground_lift
	global_basis = Basis.looking_at(-_forward, Vector3.UP)


func _set_dissolve(value: float) -> void:
	_funnel_material.set_shader_parameter(&"dissolve", value)
	_shell_material.set_shader_parameter(&"dissolve", value)
	_ground_material.set_shader_parameter(&"thickness", 0.09 * (1.0 - value))


func _apply_look() -> void:
	for material: ShaderMaterial in [_funnel_material, _ground_material]:
		material.set_shader_parameter(&"core_color", core_color)
		material.set_shader_parameter(&"edge_color", edge_color)
		material.set_shader_parameter(&"spin_speed", spin_speed)
	_shell_material.set_shader_parameter(&"spin_speed", spin_speed)
	_funnel_material.set_shader_parameter(&"core_intensity", core_intensity)


func _has_ground_below(point: Vector3) -> bool:
	_ground_query.from = point + Vector3.UP * 0.3
	_ground_query.to = point + Vector3.DOWN * ground_check_distance
	return not get_world_3d().direct_space_state.intersect_ray(_ground_query).is_empty()


## Dựng một lần: các dải xoắn ốc quanh trục Y, mỗi dải chiếm một khúc chiều cao, xoắn ribbon_turns vòng.
## Dải dựng đứng (bề ngang theo trục Y) để nhìn từ camera chéo vẫn thấy rõ.
func _build_funnel_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ribbon_count:
		# Rải đều các dải theo chiều cao, xen kẽ góc bắt đầu
		var start_h := (float(i) / float(maxi(ribbon_count - 1, 1))) * (1.0 - ribbon_span)
		start_h = clampf(start_h + rng.randf_range(-0.06, 0.06), 0.0, 1.0 - ribbon_span)
		var start_angle := rng.randf() * TAU
		var phase := rng.randf()
		var prev_top := Vector3.ZERO
		var prev_bottom := Vector3.ZERO
		for s in ribbon_segments + 1:
			var u := float(s) / float(ribbon_segments)
			var h := start_h + ribbon_span * u
			var radius := lerpf(base_radius, top_radius, pow(h, flare))
			var angle := start_angle + ribbon_turns * TAU * u
			var center := Vector3(cos(angle) * radius, h * funnel_height, sin(angle) * radius)
			var half := Vector3.UP * ribbon_width * 0.5
			var top := center + half
			var bottom := center - half
			if s > 0:
				var u0 := float(s - 1) / float(ribbon_segments)
				_add_quad(st, prev_bottom, prev_top, top, bottom, u0, u, phase, h)
			prev_top = top
			prev_bottom = bottom
	return st.commit()


## Dựng một lần: mặt phễu (đáy hẹp, đỉnh loe theo flare) làm thân mờ của lốc
func _build_shell_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 10
	for ring in rings:
		var h0 := float(ring) / float(rings)
		var h1 := float(ring + 1) / float(rings)
		var r0 := lerpf(base_radius, top_radius, pow(h0, flare)) * 0.85
		var r1 := lerpf(base_radius, top_radius, pow(h1, flare)) * 0.85
		for side in shell_sides:
			var a0 := TAU * float(side) / float(shell_sides)
			var a1 := TAU * float(side + 1) / float(shell_sides)
			var u0 := float(side) / float(shell_sides)
			var u1 := float(side + 1) / float(shell_sides)
			var p00 := Vector3(cos(a0) * r0, h0 * funnel_height, sin(a0) * r0)
			var p10 := Vector3(cos(a1) * r0, h0 * funnel_height, sin(a1) * r0)
			var p01 := Vector3(cos(a0) * r1, h1 * funnel_height, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, h1 * funnel_height, sin(a1) * r1)
			for v in [[p00, Vector2(u0, h0)], [p01, Vector2(u0, h1)], [p11, Vector2(u1, h1)], [p00, Vector2(u0, h0)], [p11, Vector2(u1, h1)], [p10, Vector2(u1, h0)]]:
				var pos: Vector3 = v[0]
				st.set_normal(Vector3(pos.x, 0.0, pos.z).normalized())
				st.set_uv(v[1])
				st.add_vertex(pos)
	return st.commit()


func _add_quad(st: SurfaceTool, a_bottom: Vector3, a_top: Vector3, b_top: Vector3, b_bottom: Vector3, u0: float, u1: float, phase: float, h: float) -> void:
	var color := Color(phase, clampf(h, 0.0, 1.0), 0.0)
	var verts: Array[Vector3] = [a_bottom, a_top, b_top, a_bottom, b_top, b_bottom]
	var uvs: Array[Vector2] = [Vector2(u0, 0.0), Vector2(u0, 1.0), Vector2(u1, 1.0), Vector2(u0, 0.0), Vector2(u1, 1.0), Vector2(u1, 0.0)]
	for j in verts.size():
		st.set_color(color)
		st.set_uv(uvs[j])
		st.add_vertex(verts[j])


static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func _ease_in(x: float) -> float:
	return x * x
