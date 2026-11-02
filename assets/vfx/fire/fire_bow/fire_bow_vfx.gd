class_name FireBowVfx
extends Node3D
## DONE 2026-10-31: ba hook generic, tụ ở đầu tên, ready một lần, release/cancel có giới hạn.
## NOT DONE: chờ người dùng gắn scene dưới Player; không tạo tên hoặc flying trail.
## NOTES: 36 hạt CPU tối đa, không đèn; warmup thu nhỏ vertex, nghỉ hoàn toàn khi idle.
enum Phase { IDLE, DRAWING, RELEASED, CANCELLING }
@export_group("Wiring")
@export var player: Player
@export_group("Arrow Tip")
## BowVisual: rest_center.z=-0.21968*1.3; đầu tên +0.7147; kéo dây lùi 0.42 m.
@export var tip_offset_rest: Vector3 = Vector3(0,0,0.429116)
@export var tip_offset_full: Vector3 = Vector3(0,0,0.009116)
@export_group("Shape")
@export var rest_scale: Vector3 = Vector3(0.10,0.13,0.20)
@export var full_scale: Vector3 = Vector3(0.34,0.34,0.38)
@export var flame_forward: float = 0.10
@export_group("Fire Coils")
@export var coil_radius: float = 0.24
@export var coil_length: float = 0.66
@export_range(0.0,1.0,0.01) var coil_origin_ratio: float = 0.65
@export var coil_width: float = 0.16
@export var coil_turns: float = 0.80
@export_range(12,64,1) var coil_segments: int = 36
@export var coil_speed: float = 5.0
@export var coil_start_scale: float = 0.4
@export_group("Particles")
@export var gather_radius: float = 0.28
@export var gather_speed: Vector2 = Vector2(0.5,0.7)
@export var release_speed: Vector2 = Vector2(1.0,2.0)
@export_group("Timing")
@export var appear_time: float = 0.06
@export var ready_time: float = 0.16
@export var ready_expansion: float = 0.35
@export var ready_threshold: float = 1.0
@export var release_time: float = 0.16
@export var cancel_time: float = 0.18
@export var gather_lifetime: float = 0.45
@export var prepare_on_ready: bool = true
@export var prepare_frames: int = 3
@export_group("Budget")
@export_range(1,24,1) var gather_particles: int = 24
@export_range(1,15,1) var release_particles: int = 12
@export_range(1,24,1) var minimum_particles: int = 4
@export_group("Palette")
@export var core_color: Color = Color("ff6136")
@export var hot_color: Color = Color("ff3215")
@export var flame_color: Color = Color("e61811")
@export var edge_color: Color = Color("7a050a")
@export var flow_speed: float = 1.6
@export var curl_amount: float = 0.10
@export var edge_width: float = 0.025
var _phase: Phase = Phase.IDLE
var _amount: float = 0.0
var _age: float = 0.0
var _clock: float = 0.0
var _ready_left: float = 0.0
var _ready_latched: bool = false
var _epoch: int = 0
@onready var _coils: MeshInstance3D = $Coils
@onready var _coil_mat: ShaderMaterial = $Coils.material_override as ShaderMaterial
@onready var _flame: MeshInstance3D = $Flame
@onready var _gather: CPUParticles3D = $Gather
@onready var _burst: CPUParticles3D = $Release
@onready var _body_mat: ShaderMaterial = $Flame.material_override as ShaderMaterial
@onready var _gather_mat: ShaderMaterial = $Gather.mesh.surface_get_material(0) as ShaderMaterial
@onready var _burst_mat: ShaderMaterial = $Release.mesh.surface_get_material(0) as ShaderMaterial
var _materials: Array[ShaderMaterial] = []

## Nối đúng chữ ký hook đã có, không truy cập hay sửa BowVisual.
func _ready() -> void:
	top_level = true
	set_process(false)
	_materials = [_body_mat,_gather_mat,_burst_mat,_coil_mat]
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter(&"core_color",core_color)
		mat.set_shader_parameter(&"hot_color",hot_color)
		mat.set_shader_parameter(&"flame_color",flame_color)
		mat.set_shader_parameter(&"edge_color",edge_color)
		mat.set_shader_parameter(&"flow_speed",flow_speed)
		mat.set_shader_parameter(&"curl",curl_amount)
		mat.set_shader_parameter(&"edge_width",edge_width)
		mat.set_shader_parameter(&"coil_speed",coil_speed)
	_gather.amount = clampi(gather_particles,1,24)
	_burst.amount = clampi(release_particles,1,39-_gather.amount)
	_gather_mat.set_shader_parameter(&"gather_count",_gather.amount)
	_gather_mat.set_shader_parameter(&"minimum_count",mini(minimum_particles,_gather.amount))
	_gather.lifetime = maxf(gather_lifetime,0.01)
	_burst.lifetime = maxf(release_time,0.01)
	_gather.initial_velocity_min = maxf(gather_speed.x,0.0)
	_gather.initial_velocity_max = maxf(gather_speed.y,_gather.initial_velocity_min)
	_burst.initial_velocity_min = maxf(release_speed.x,0.0)
	_burst.initial_velocity_max = maxf(release_speed.y,_burst.initial_velocity_min)
	_flame.position.z = flame_forward
	_build_coils()
	_build_gather_points()
	reset()
	if is_instance_valid(player):
		player.fusion_bow_draw.connect(_on_draw)
		player.fusion_bow_released.connect(_on_released)
		player.fusion_bow_aim_ended.connect(_on_aim_ended)
	if prepare_on_ready and DisplayServer.get_name() != "headless":
		await _prepare()

## Chỉ chạy trong lúc kéo hoặc tàn; không cấp phát mảng/node/material mỗi frame.
func _process(delta: float) -> void:
	_age += delta
	_clock += delta
	_ready_left = maxf(0.0,_ready_left-delta)
	var pulse: float = sin(_ready_left/maxf(ready_time,0.001)*PI)
	var opacity: float = 1.0
	if _phase == Phase.DRAWING:
		if not is_instance_valid(player):
			reset()
			return
		_sync_tip()
		opacity = smoothstep(0.0,maxf(appear_time,0.001),_age)
	elif _phase == Phase.RELEASED:
		opacity = pow(maxf(1.0-_age/maxf(release_time,0.001),0.0),2.0)
	elif _phase == Phase.CANCELLING:
		opacity = pow(maxf(1.0-_age/maxf(cancel_time,0.001),0.0),2.0)
	if opacity <= 0.0 and _phase != Phase.DRAWING:
		reset()
		return
	_flame.scale = rest_scale.lerp(full_scale,smoothstep(0.0,1.0,_amount))*(1.0+pulse*ready_expansion)
	_coils.scale = Vector3.ONE * lerpf(coil_start_scale,1.0,smoothstep(0.0,1.0,_amount))*(1.0+pulse*ready_expansion)
	_coil_mat.set_shader_parameter(&"clock",_clock)
	_coil_mat.set_shader_parameter(&"pulse",pulse)
	_body_mat.set_shader_parameter(&"clock",_clock)
	_body_mat.set_shader_parameter(&"pulse",pulse)
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter(&"opacity",opacity)

## Draw(0) phát sau released không được mở lại tụ lực; lượt mới phải có amount dương.
func _on_draw(element_id: StringName, amount: float) -> void:
	if element_id != &"fire" or not is_instance_valid(player):
		return
	if (_phase == Phase.RELEASED or _phase == Phase.CANCELLING) and amount <= 0.0:
		return
	if _phase != Phase.DRAWING:
		_epoch += 1
		_phase = Phase.DRAWING
		_age = 0.0
		_ready_latched = false
		_ready_left = 0.0
		_burst.emitting = false
		_burst.hide()
		_show_live()
		_gather.restart()
		_gather.emitting = true
	_amount = clampf(amount,0.0,1.0)
	_gather_mat.set_shader_parameter(&"charge",_amount)
	_sync_tip()
	if _amount >= ready_threshold and not _ready_latched:
		_ready_latched = true
		_ready_left = maxf(ready_time,0.001)
	set_process(true)

## Chỉ phát burst ở đầu tên; flying trail do fusion hiện có sở hữu.
func _on_released(element_id: StringName) -> void:
	if element_id != &"fire" or _phase != Phase.DRAWING:
		return
	_epoch += 1
	_sync_tip()
	_phase = Phase.RELEASED
	_age = 0.0
	_ready_left = 0.0
	_gather.emitting = false
	_burst.show()
	_burst.restart()
	_burst.emitting = true
	set_process(true)

## Aim ended có ưu tiên cao hơn release; dừng phát mọi hạt và chỉ giữ đuôi fade ngắn.
func _on_aim_ended(element_id: StringName) -> void:
	if element_id != &"fire" or _phase == Phase.IDLE:
		return
	_epoch += 1
	_phase = Phase.CANCELLING
	_age = 0.0
	_ready_left = 0.0
	_gather.emitting = false
	_burst.emitting = false
	set_process(true)

## Chỗ neo lấy hoàn toàn từ hook world grip; không dò private node của teammate.
func _sync_tip() -> void:
	var grip: Transform3D = player.get_bow_grip_transform()
	global_transform = Transform3D(grip.basis.orthonormalized(),grip*tip_offset_rest.lerp(tip_offset_full,_amount))

## Bật phần kéo và khôi phục shader nếu hook đến ngay giữa prewarm.
func _show_live() -> void:
	_body_mat.set_shader_parameter(&"pulse",0.0)
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter(&"prewarm_scale",1.0)
		mat.set_shader_parameter(&"opacity",0.0)
	_coils.show()
	_flame.show()
	_gather.show()

## Dùng chung cho idle và tái sử dụng; không để lại burst, timer hoặc latch của lượt cũ.
func reset() -> void:
	_epoch += 1
	_phase = Phase.IDLE
	_ready_latched = false
	_ready_left = 0.0
	_amount = 0.0
	_age = 0.0
	_clock = 0.0
	_coils.hide()
	_flame.hide()
	_gather.emitting = false
	_burst.emitting = false
	_gather.hide()
	_burst.hide()
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter(&"opacity",0.0)
		mat.set_shader_parameter(&"pulse",0.0)
		mat.set_shader_parameter(&"charge",0.0)
	set_process(false)

## Các điểm có vận tốc hướng vào tâm, giữ số hạt cố định khi amount đổi liên tục.
func _build_gather_points() -> void:
	var points: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	for i: int in range(_gather.amount):
		var angle: float = float(i)/_gather.amount*TAU
		var p: Vector3 = Vector3(cos(angle),sin(angle),sin(angle*2.0)*0.35)*maxf(gather_radius,0.01)
		points.append(p)
		normals.append(-p.normalized())
	_gather.emission_points = points
	_gather.emission_normals = normals

## Vertex được thu nhỏ trong shader, không dựa vào transparency; không dọn mất lượt đến giữa prewarm.
func _prepare() -> void:
	var epoch: int = _epoch
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter(&"prewarm_scale",0.000001)
		mat.set_shader_parameter(&"opacity",1.0)
	_coils.show()
	_flame.show()
	_gather.show()
	_burst.show()
	_gather.emitting = true
	_burst.restart()
	_burst.emitting = true
	for frame: int in range(prepare_frames):
		await RenderingServer.frame_post_draw
	if epoch != _epoch:
		return
	reset()
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter(&"prewarm_scale",1.0)


## Hai dải xoắn có tiết diện thu vào đầu tên, dựng một lần rồi shader cuộn quanh trục bắn.
func _build_coils() -> void:
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var count: int = clampi(coil_segments,12,64)
	for strand: int in range(2):
		var base: int = vertices.size()
		for step: int in range(count + 1):
			var t: float = float(step)/count
			var angle: float = t*TAU*coil_turns + float(strand)*PI + sin(t*PI)*0.65
			var radius: float = maxf(coil_radius,0.01)*lerpf(1.0,0.12,t)
			var width: float = maxf(coil_width,0.001)*pow(maxf(sin(t*PI),0.0),0.8)*(0.8+0.2*sin(t*17.0+float(strand)*2.0))
			for side: int in range(2):
				var r: float = radius+(float(side)-0.5)*width
				vertices.append(Vector3(cos(angle)*r,sin(angle)*r,(t-coil_origin_ratio)*maxf(coil_length,0.01)))
				uvs.append(Vector2(t,float(side)))
		for step: int in range(count):
			var a: int = base+step*2
			indices.append_array(PackedInt32Array([a,a+2,a+1,a+1,a+2,a+3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_coils.mesh = mesh
