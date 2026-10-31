class_name FlameBreathVfx
extends Node3D
## Phun lửa theo concept 2026-10-31: thân có tiết diện, texture cuộn, ngọn phụ theo chiều phun.
## DONE: ba emitter CPU có giới hạn, mesh dựng một lần, giữ hitbox và signal cũ.
## NOT DONE: chờ duyệt mỹ thuật; chưa đo bản export/cache sạch.
## NOTES: chỉ hình ảnh; không thay thời điểm Q, sát thương hoặc lửa lan.

const STATE_NAME := &"FlameBreath"

@export_group("Wiring")
## HitboxComponent của luồng lửa (Model/FlameHitbox); kích thước vùng trúng lấy từ đây
@export var hitbox: HitboxComponent
## Node xoay theo hướng nhân vật (Model); miệng lửa bám theo hướng của nó
@export var follow: Node3D
@export_group("Shape")
## Độ cao miệng lửa so với chân (m)
@export var nozzle_height: float = 1.0
## Miệng lửa lùi/tiến trước mặt (m)
@export var nozzle_forward: float = 0.15
## Nâng vệt sáng sàn lên chút để không z-fighting với sàn
@export var floor_offset: float = 0.04
## Cỡ hạt lõi theo tỉ lệ cạnh nhỏ của vùng trúng
@export var particle_width_ratio: float = 0.22
## Ngọn phụ tập trung ở đầu luồng, không rải thành từng cục từ miệng tới đích.
@export_range(0.0, 0.9, 0.01) var crest_particle_start: float = 0.65
## Thân lửa thấp hơn hộp va chạm cho dáng dẹt dễ đọc từ camera trên cao
@export var body_height_ratio: float = 0.84
## Số vòng / số cạnh của mesh thân lửa; nhiều hơn mượt hơn nhưng nặng hơn (dựng 1 lần lúc tải)
@export_range(8, 48, 1) var body_rings: int = 24
@export_range(8, 32, 1) var body_sides: int = 16
## Độ phồng của mặt mang texture để luồng lửa có chiều sâu ở góc camera gameplay.
@export var body_lift_ratio: float = 0.14
## Cỡ hạt khói theo tỉ lệ cạnh nhỏ của vùng trúng
@export var smoke_width_ratio: float = 0.35
## Tốc độ hạt theo tỉ lệ (chiều dài / lifetime) để hạt vừa chạm cuối tầm
@export var particle_speed_min_ratio: float = 0.6
@export var particle_speed_max_ratio: float = 0.85
## Độ toả của hạt theo tỉ lệ bề ngang
@export var spread_width_ratio: float = 0.25
@export_group("Particle Budget")
@export_range(1, 12, 1) var core_count: int = 6
@export_range(1, 16, 1) var ember_count: int = 8
@export_range(1, 8, 1) var smoke_count: int = 4
@export_group("Preparation")
## Vẽ thử mọi thứ trong vài khung lúc tải để biên dịch shader trước, tránh giật ở lần phun đầu tiên
@export var prepare_on_ready: bool = true
@export var preparation_frames: int = 3
@export_group("Timing")
## Thời gian lửa tắt dần sau khi hết phun (s)
@export var fade_time: float = 0.35
## Tắt từ miệng ra đầu để lửa còn lại không bị cắt đồng loạt.
@export var release_travel_time: float = 0.22
## Cỡ quầng nóng ở miệng lúc vung tay (trước active_start)
@export var ignition_size: float = 0.35
## Thời gian thân lửa bùng từ 0 lên đủ sáng (s); ngắn = cảm giác "nổ" mạnh
@export var release_time: float = 0.05
@export_group("Ignition Punch")
@export var ignition_pop: float = 1.6
@export var ignition_decay: float = 0.035
@export var pressure_boost: float = 0.15
@export var light_pop: float = 0.35
@export_group("Light")
@export var light_energy: float = 2.0
## Giới hạn vùng đèn để tầm xa không tăng chi phí phủ sáng toàn phòng.
@export var light_max_range: float = 6.0
@export var preparation_flash_scale: float = 0.01
## Biên độ nhấp nháy của đèn (0 = không nhấp nháy)
@export var light_flicker: float = 0.18
@export var ground_glow_intensity: float = 0.8

var _active: float = 0.0
var _fade: float = 0.0
var _ignition: float = 0.0
var _clock: float = 0.0
var _pool: Array[FlameImpact] = []
# Cache để _fit_shape (mỗi lần phun) không tạo mảng / get_node
var _streams: Array[CPUParticles3D] = []
var _hitbox_shape: BoxShape3D

@onready var _nozzle: Node3D = $Nozzle
@onready var _body: MeshInstance3D = $Nozzle/FlameBody
@onready var _core: CPUParticles3D = $Nozzle/Core
@onready var _core_mat: ShaderMaterial = $Nozzle/Core.mesh.surface_get_material(0) as ShaderMaterial
@onready var _embers: CPUParticles3D = $Nozzle/Embers
@onready var _smoke: CPUParticles3D = $Nozzle/Smoke
@onready var _heat: MeshInstance3D = $Nozzle/Heat
@onready var _ground: MeshInstance3D = $Nozzle/GroundGlow
@onready var _light: OmniLight3D = $Nozzle/Light
@onready var _body_mat: ShaderMaterial = $Nozzle/FlameBody.material_override as ShaderMaterial
@onready var _ground_mat: ShaderMaterial = $Nozzle/GroundGlow.material_override as ShaderMaterial
@onready var _heat_mat: ShaderMaterial = $Nozzle/Heat.mesh.surface_get_material(0) as ShaderMaterial


## ĐẠT: dựng mesh thân lửa, gom pool, nối signal. Thiếu hitbox/follow thì VFX im lặng (không lỗi).
func _ready() -> void:
	set_process(false)
	_heat.hide()
	_body.hide()
	_ground.hide()
	_build_body()
	# Ngọn phụ cũng có thể tích, tránh những tấm atlas quay theo camera ở đầu luồng.
	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = 0.32
	core_mesh.height = 1.0
	core_mesh.radial_segments = 8
	core_mesh.rings = 4
	core_mesh.material = _core_mat
	_core.mesh = core_mesh
	_core_mat.set_shader_parameter(&"burning_volume", true)
	_streams = [_core, _embers, _smoke]
	_core.amount = maxi(core_count, 1)
	_embers.amount = maxi(ember_count, 1)
	_smoke.amount = maxi(smoke_count, 1)
	for child: Node in $ImpactPool.get_children():
		_pool.append(child as FlameImpact)
	if hitbox == null or follow == null:
		return
	_hitbox_shape = (hitbox.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	hitbox.activated.connect(_on_activated)
	hitbox.hit.connect(_on_hit)
	hitbox.deactivated.connect(_on_deactivated)
	var player: Player = get_parent() as Player
	if player:
		if not player.is_node_ready():
			await player.ready
		player.state_machine.state_changed.connect(_on_state_changed)
	if prepare_on_ready and DisplayServer.get_name() != "headless":
		await _prepare_render()


## ĐẠT: chỉ chạy khi đang có lửa (vung tay -> phun -> tắt dần), xong thì tự set_process(false).
## Ba pha: _ignition (quầng nóng ở miệng) -> _active (đang phun) -> _fade (tắt dần).
func _process(delta: float) -> void:
	_align()
	_clock += delta
	_body_mat.set_shader_parameter(&"clock", _clock)
	_ground_mat.set_shader_parameter(&"clock", _clock)
	if _ignition > 0.0:
		_ignition = maxf(0.0, _ignition - delta)
		_heat.scale = Vector3.ONE * ignition_size * (1.0 - _ignition * 0.5)
		return
	if _active > 0.0:
		_active -= delta
		var punch: float = exp(-_clock / maxf(ignition_decay, 0.001))
		_heat.scale = Vector3.ONE * ignition_size * (1.0 + ignition_pop * punch)
		_heat_mat.set_shader_parameter(&"intensity", 0.6 + punch)
		_body_mat.set_shader_parameter(&"pressure", 1.0 + pressure_boost * punch)
		var advance: float = clampf(_clock / maxf(release_time, 0.001), 0.0, 1.0)
		_body_mat.set_shader_parameter(&"front", 1.0 - pow(1.0 - advance, 3.0))
		_body_mat.set_shader_parameter(&"strength", minf(_clock / maxf(release_time, 0.001), 1.0))
		_light.light_energy = light_energy * (1.0 - light_flicker * randf()) * (1.0 + light_pop * punch)
		if _active <= 0.0:
			_set_emitting(false)
			_fade = fade_time
		return
	_fade = maxf(0.0, _fade - delta)
	var k: float = _fade / maxf(fade_time, 0.001)
	_body_mat.set_shader_parameter(&"pressure", 1.0)
	_body_mat.set_shader_parameter(&"strength", 1.0 if k > 0.0 else 0.0)
	_body_mat.set_shader_parameter(&"retreat", clampf((fade_time - _fade) / maxf(release_travel_time, 0.001), 0.0, 1.0))
	_ground_mat.set_shader_parameter(&"strength", k * ground_glow_intensity)
	_light.light_energy = light_energy * k
	_heat_mat.set_shader_parameter(&"intensity", k)
	if _fade <= 0.0:
		_heat.hide()
		_body.hide()
		_ground.hide()
		set_process(false)


## ĐẠT: miệng lửa bám hướng ngang của Model (bỏ trục y để lửa không chúi xuống sàn khi nhân vật nghiêng).
func _align() -> void:
	var forward: Vector3 = follow.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return
	forward = forward.normalized()
	_core_mat.set_shader_parameter(&"stream_direction", forward)
	_nozzle.global_basis = Basis.looking_at(-forward, Vector3.UP)
	_nozzle.global_position = follow.global_position + Vector3.UP * nozzle_height + forward * nozzle_forward


## ĐẠT: hitbox bật = bắt đầu phun; thời gian phun lấy từ hitbox nên đổi active_time trong .tres là VFX theo.
func _on_activated(_attack: AttackData) -> void:
	_body.show()
	_ground.show()
	_clock = 0.0
	_body_mat.set_shader_parameter(&"front", 0.0)
	_body_mat.set_shader_parameter(&"retreat", 0.0)
	_ignition = 0.0
	_active = hitbox.get_active_duration()
	_fade = fade_time
	_fit_shape()
	_align()
	_set_emitting(true)
	_heat.show()
	_ground_mat.set_shader_parameter(&"strength", ground_glow_intensity)
	set_process(true)


## ĐẠT: co giãn thân lửa, vệt sàn, đèn và tốc độ hạt theo hộp va chạm thật (đã set_reach / set_cross_section).
## Material/mesh thay đổi được đánh dấu local_to_scene để các instance không ghi đè nhau.
func _fit_shape() -> void:
	var box: BoxShape3D = _hitbox_shape
	var reach: float = hitbox.get_reach()
	var length: float = maxf(reach - nozzle_forward, 0.01)
	_body.scale = Vector3(box.size.x, box.size.y * body_height_ratio, length)
	_body.position = Vector3.ZERO
	var quad: QuadMesh = _ground.mesh as QuadMesh
	quad.size = Vector2(box.size.x, reach)
	_ground.position = Vector3(0.0, -nozzle_height + floor_offset, reach * 0.5 - nozzle_forward)
	for particles: CPUParticles3D in _streams:
		particles.visibility_aabb = AABB(Vector3(-box.size.x, -box.size.y, -1.0), Vector3(box.size.x * 2.0, box.size.y * 3.0, length + 2.0))
		particles.initial_velocity_min = length / particles.lifetime * particle_speed_min_ratio
		particles.initial_velocity_max = length / particles.lifetime * particle_speed_max_ratio
		particles.spread = rad_to_deg(atan2(box.size.x * spread_width_ratio, length))
		particles.damping_min = 0.0
		particles.damping_max = 0.0
	_smoke.scale_amount_min = minf(box.size.x, box.size.y) * smoke_width_ratio * 0.5
	_smoke.scale_amount_max = _smoke.scale_amount_min
	_heat.scale = Vector3.ONE * minf(ignition_size, box.size.x)
	# Chặn vùng đèn theo export để tầm xa không phủ sáng cả phòng.
	_light.omni_range = minf(light_max_range, maxf(reach, maxf(box.size.x, box.size.y)))
	_core.scale_amount_min = minf(box.size.x, box.size.y) * particle_width_ratio
	_core.scale_amount_max = _core.scale_amount_min * 1.5
	_core.position.z = length * crest_particle_start
	_core.emission_sphere_radius = minf(box.size.x, box.size.y) * 0.18
	_core.initial_velocity_min *= 1.0 - crest_particle_start
	_core.initial_velocity_max *= 1.0 - crest_particle_start



## Ngắt phát cả ba nhóm hạt cùng hitbox, không tự kéo dài gameplay.
func _set_emitting(on: bool) -> void:
	for particles: CPUParticles3D in _streams:
		particles.emitting = on


## ĐẠT: lấy node rảnh trong pool; hết node rảnh thì cắt lượt sắp xong nhất (không instantiate thêm).
func _on_hit(target: HurtboxComponent) -> void:
	var chosen: FlameImpact = _pool[0]
	for slot: FlameImpact in _pool:
		if slot.remaining <= 0.0:
			chosen = slot
			break
		if slot.remaining < chosen.remaining:
			chosen = slot
	chosen.play(target)


## ĐẠT: vào state = bật quầng nóng ở miệng trong lúc vung tay (trước active_start);
## bị ngắt giữa chừng (dash, bị đánh) = cho lửa tắt dần ngay.
func _on_state_changed(from: StringName, to: StringName) -> void:
	if to == STATE_NAME:
		var player: Player = get_parent() as Player
		var data: FlameBreathData = player.get_ability(FlameBreathData.ID) as FlameBreathData
		if data:
			_ignition = data.active_start
			_heat.show()
			_heat_mat.set_shader_parameter(&"intensity", 1.0)
			set_process(true)
	elif from == STATE_NAME and (_active > 0.0 or _ignition > 0.0):
		_ignition = 0.0
		_active = 0.0
		_fade = fade_time
		_set_emitting(false)


## ĐẠT: renderer Compatibility chỉ biên dịch shader khi thật sự vẽ, nên vẽ gần như trong suốt vài khung lúc tải.
## Chỉ làm cho VFX này, không warmup cả map.
func _prepare_render() -> void:
	if _active > 0.0 or _fade > 0.0 or _ignition > 0.0:
		return
	_align()
	_body.show()
	_ground.show()
	_body_mat.set_shader_parameter(&"strength", 0.001)
	# Chớp mới có biến thể billboard riêng, phải vẽ thật trước lần Q đầu.
	_heat.scale = Vector3.ONE * preparation_flash_scale
	_heat_mat.set_shader_parameter(&"intensity", 0.001)
	_heat.show()
	_ground_mat.set_shader_parameter(&"strength", 0.001)
	for particles: CPUParticles3D in _streams:
		particles.transparency = 0.999
	_set_emitting(true)
	for slot: FlameImpact in _pool:
		slot.prepare_render()
	for frame: int in range(preparation_frames):
		await RenderingServer.frame_post_draw
	for particles: CPUParticles3D in _streams:
		particles.transparency = 0.0
		particles.restart()
	_set_emitting(_active > 0.0)
	# Nếu người chơi vừa phun khi chờ frame_post_draw, không dọn mất chiêu đang chạy.
	if _active > 0.0 or _fade > 0.0:
		return
	_body_mat.set_shader_parameter(&"strength", 0.0)
	_ground_mat.set_shader_parameter(&"strength", 0.0)
	_body.hide()
	_ground.hide()
	if _ignition <= 0.0:
		_heat.hide()
		_heat_mat.set_shader_parameter(&"intensity", 0.0)


## Các bầu lửa chồng lên lõi liên tục, có chiều sâu ở mọi góc; chỉ dựng khi tải.
func _build_body() -> void:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var rings: int = clampi(body_rings / 3, 6, 16)
	var sides: int = clampi(body_sides, 8, 12)
	for puff: int in range(13):
		var core: bool = puff == 0
		var t: float = float(puff - 1) / 11.0
		var center: float = 0.20 + t * 0.62
		var radius: float = 0.10 + t * 0.13
		var angle: float = float(puff) * 2.4
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius * (0.5 + body_lift_ratio)
		var base: int = vertices.size()
		for ring: int in range(rings + 1):
			var h: float = float(ring) / rings
			var profile: float = pow(maxf(sin(h * PI), 0.0), 0.7)
			for side: int in range(sides + 1):
				var u: float = float(side) / sides
				var theta: float = u * TAU
				var r: float = profile * (0.14 if core else radius)
				var z: float = h if core else center + (h - 0.5) * (0.32 + t * 0.12)
				var drift: Vector2 = Vector2.ZERO if core else offset * sin(h * PI)
				vertices.append(Vector3(cos(theta) * r + drift.x, sin(theta) * r + drift.y, z))
				normals.append(Vector3(cos(theta), sin(theta), 0.25 * (h - 0.5)).normalized())
				uvs.append(Vector2(u, z))
				colors.append(Color(1.0 if core else 0.0, h, float(puff) / 13.0, 1.0))
		for ring: int in range(rings):
			for side: int in range(sides):
				var a: int = base + ring * (sides + 1) + side
				var b: int = a + sides + 1
				indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_body.mesh = mesh


## Ngắt phát hạt theo hitbox, kể cả khi kỹ năng bị hủy sớm.
func _on_deactivated() -> void:
	if _active <= 0.0:
		return
	_active = 0.0
	_fade = fade_time
	_set_emitting(false)
