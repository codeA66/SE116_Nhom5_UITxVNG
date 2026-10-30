class_name FlameBreathVfx
extends Node3D
## Hình ảnh kỹ năng Phun Lửa (Q): thân lửa liền khối (mesh dựng bằng code + shader), lõi / tàn lửa / khói (GPUParticles),
## quầng nóng ở miệng lúc vung tay, vệt sáng trên sàn, đèn cam nhấp nháy, và hiệu ứng trúng (pool FlameImpact).
## Nằm dưới gốc Player, KHÔNG dưới Model: foxy_player.gd ghi đè material mọi mesh dưới Model.
## Chỉ nghe signal (hitbox.activated / hitbox.hit / state_changed), không dò va chạm mỗi frame; state không biết VFX tồn tại.
##
## TRẠNG THÁI (2026-10-30, đã chạy thử trong tests/fire/sandbox/fire_sandbox.tscn, cửa sổ + headless):
## - ĐẠT: khớp tầm/độ rộng theo FlameBreathData (đã chụp tầm 0.5 m, 4.5 m, 20 m; rộng 0.3 m, 2.4 m, 10 m).
## - ĐẠT: đọc rõ trên nền sáng và nền tối; tắt dần bằng khói, không cắt ngang.
## - ĐẠT: khung chậm nhất lúc phun thường 9-20 ms (tầm 4.5 m ~9-10 ms, tầm 20 m ~13.5 ms, rộng 10 m ~17-20 ms).
## - CHƯA RÕ: đo 2 lần, mỗi lần có MỘT khung giật 44-52 ms nhưng rơi vào cấu hình khác nhau (lần 1 tầm 20 m, lần 2 nền tối)
##   -> chưa chứng minh do VFX; có thể do máy / chụp ảnh. Cần đo bằng profiler trong game thật trước khi kết luận.
## - CHƯA ĐẠT (thẩm mỹ): rộng 10 m thân lửa thành cái đĩa dẹt; đúng vùng trúng nhưng xấu. Bỏ qua nếu designer không chỉnh rộng vậy.
## - LƯU Ý: _on_state_changed gắn cứng tên state "FlameBreath" và id "flame_breath"; đổi tên state/kỹ năng phải sửa ở đây.

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
## Thân lửa thấp hơn hộp va chạm cho dáng dẹt dễ đọc từ camera trên cao
@export var body_height_ratio: float = 0.64
## Số vòng / số cạnh của mesh thân lửa; nhiều hơn mượt hơn nhưng nặng hơn (dựng 1 lần lúc tải)
@export_range(8, 48, 1) var body_rings: int = 24
@export_range(8, 32, 1) var body_sides: int = 16
## Dáng thân lửa (tỉ lệ theo bề ngang): cổ hẹp ở miệng -> loe dần -> phình ở "đỉnh" -> thu nhọn ở cuối tầm
@export var neck_ratio: float = 0.035
@export var stream_width_ratio: float = 0.44
@export var bloom_power: float = 0.65
@export var crest_position: float = 0.76
@export var crest_span: float = 0.24
@export var crest_strength: float = 0.56
@export var tip_start: float = 0.88
## Cỡ hạt khói theo tỉ lệ cạnh nhỏ của vùng trúng
@export var smoke_width_ratio: float = 0.35
## Tốc độ hạt theo tỉ lệ (chiều dài / lifetime) để hạt vừa chạm cuối tầm
@export var particle_speed_min_ratio: float = 0.6
@export var particle_speed_max_ratio: float = 0.85
## Độ toả của hạt theo tỉ lệ bề ngang
@export var spread_width_ratio: float = 0.25
@export_group("Preparation")
## Vẽ thử mọi thứ trong vài khung lúc tải để biên dịch shader trước, tránh giật ở lần phun đầu tiên
@export var prepare_on_ready: bool = true
@export var preparation_frames: int = 3
@export_group("Timing")
## Thời gian lửa tắt dần sau khi hết phun (s)
@export var fade_time: float = 0.35
## Cỡ quầng nóng ở miệng lúc vung tay (trước active_start)
@export var ignition_size: float = 0.65
## Thời gian thân lửa bùng từ 0 lên đủ sáng (s); ngắn = cảm giác "nổ" mạnh
@export var release_time: float = 0.05
@export_group("Light")
@export var light_energy: float = 2.0
## Biên độ nhấp nháy của đèn (0 = không nhấp nháy)
@export var light_flicker: float = 0.18
@export var ground_glow_intensity: float = 0.8

var _active: float = 0.0
var _fade: float = 0.0
var _ignition: float = 0.0
var _clock: float = 0.0
var _pool: Array[FlameImpact] = []
# Cache để _fit_shape (mỗi lần phun) không tạo mảng / get_node
var _streams: Array[GPUParticles3D] = []
var _hitbox_shape: BoxShape3D

@onready var _nozzle: Node3D = $Nozzle
@onready var _body: MeshInstance3D = $Nozzle/FlameBody
@onready var _core: GPUParticles3D = $Nozzle/Core
@onready var _embers: GPUParticles3D = $Nozzle/Embers
@onready var _smoke: GPUParticles3D = $Nozzle/Smoke
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
	_build_body()
	_streams = [_core, _embers, _smoke]
	for child: Node in $ImpactPool.get_children():
		_pool.append(child as FlameImpact)
	if hitbox == null or follow == null:
		return
	_hitbox_shape = (hitbox.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	hitbox.activated.connect(_on_activated)
	hitbox.hit.connect(_on_hit)
	if prepare_on_ready and DisplayServer.get_name() != "headless":
		await _prepare_render()
	var player := get_parent() as Player
	if player:
		if not player.is_node_ready():
			await player.ready
		player.state_machine.state_changed.connect(_on_state_changed)


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
		_body_mat.set_shader_parameter(&"strength", minf(_clock / maxf(release_time, 0.001), 1.0))
		_light.light_energy = light_energy * (1.0 - light_flicker * randf())
		if _active <= 0.0:
			_set_emitting(false)
			_fade = fade_time
		return
	_fade = maxf(0.0, _fade - delta)
	var k: float = _fade / maxf(fade_time, 0.001)
	_body_mat.set_shader_parameter(&"strength", k * k)
	_ground_mat.set_shader_parameter(&"strength", k * ground_glow_intensity)
	_light.light_energy = light_energy * k
	_heat_mat.set_shader_parameter(&"intensity", k)
	if _fade <= 0.0:
		_heat.hide()
		set_process(false)


## ĐẠT: miệng lửa bám hướng ngang của Model (bỏ trục y để lửa không chúi xuống sàn khi nhân vật nghiêng).
func _align() -> void:
	var forward: Vector3 = follow.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return
	forward = forward.normalized()
	_nozzle.global_basis = Basis.looking_at(-forward, Vector3.UP)
	_nozzle.global_position = follow.global_position + Vector3.UP * nozzle_height + forward * nozzle_forward


## ĐẠT: hitbox bật = bắt đầu phun; thời gian phun lấy từ hitbox nên đổi active_time trong .tres là VFX theo.
func _on_activated(_attack: AttackData) -> void:
	_clock = 0.0
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
## LƯU Ý: sửa thẳng ParticleProcessMaterial / QuadMesh của scene; ổn vì chỉ có một player.
## Nếu sau này nhiều nhân vật cùng dùng scene này thì phải bật resource_local_to_scene cho các resource đó.
func _fit_shape() -> void:
	var box := _hitbox_shape
	var reach: float = hitbox.get_reach()
	var length: float = maxf(reach - nozzle_forward, 0.01)
	_body.scale = Vector3(box.size.x, box.size.y * body_height_ratio, length)
	_body.position = Vector3.ZERO
	var quad := _ground.mesh as QuadMesh
	quad.size = Vector2(box.size.x, reach)
	_ground.position = Vector3(0.0, -nozzle_height + floor_offset, reach * 0.5 - nozzle_forward)
	for particles: GPUParticles3D in _streams:
		particles.visibility_aabb = AABB(Vector3(-box.size.x, -box.size.y, -1.0), Vector3(box.size.x * 2.0, box.size.y * 3.0, length + 2.0))
		var mat := particles.process_material as ParticleProcessMaterial
		mat.initial_velocity_min = length / particles.lifetime * particle_speed_min_ratio
		mat.initial_velocity_max = length / particles.lifetime * particle_speed_max_ratio
		mat.spread = rad_to_deg(atan2(box.size.x * spread_width_ratio, length))
		mat.damping_min = 0.0
		mat.damping_max = 0.0
	var smoke_material := _smoke.process_material as ParticleProcessMaterial
	smoke_material.scale_min = minf(box.size.x, box.size.y) * smoke_width_ratio * 0.5
	smoke_material.scale_max = smoke_material.scale_min
	_heat.scale = Vector3.ONE * minf(ignition_size, box.size.x)
	# LƯU Ý: tầm 20 m -> đèn phủ 20 m; chưa thấy gây giật (đo 13.5 ms) nhưng chiêu tầm xa nên cân nhắc giới hạn
	_light.omni_range = maxf(reach, maxf(box.size.x, box.size.y))
	var core_material := _core.process_material as ParticleProcessMaterial
	core_material.scale_min = minf(box.size.x, box.size.y) * particle_width_ratio
	core_material.scale_max = core_material.scale_min * 1.5
	var core_mesh := _core.draw_pass_1 as QuadMesh
	core_mesh.size = Vector2.ONE * minf(box.size.x * 0.6, box.size.y * 0.65)


func _set_emitting(on: bool) -> void:
	for particles: GPUParticles3D in _streams:
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
		var player := get_parent() as Player
		var data := player.get_ability(FlameBreathData.ID) as FlameBreathData
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
	_align()
	_body_mat.set_shader_parameter(&"strength", 0.001)
	_ground_mat.set_shader_parameter(&"strength", 0.001)
	for particles: GPUParticles3D in _streams:
		particles.transparency = 0.999
	_set_emitting(true)
	for slot: FlameImpact in _pool:
		slot.prepare_render()
	for frame: int in range(preparation_frames):
		await RenderingServer.frame_post_draw
	for particles: GPUParticles3D in _streams:
		particles.transparency = 0.0
		particles.restart()
	_set_emitting(false)
	_body_mat.set_shader_parameter(&"strength", 0.0)
	_ground_mat.set_shader_parameter(&"strength", 0.0)


## ĐẠT: thân và đầu lửa chung một mesh ống (vòng x cạnh) để không có đường nối; chỉ dựng một lần lúc tải.
## Mesh dài 1 theo trục z, rộng 1; _fit_shape co giãn bằng scale.
func _build_body() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for ring: int in range(body_rings + 1):
		var t: float = float(ring) / float(body_rings)
		var stream: float = lerpf(neck_ratio, stream_width_ratio, pow(t, bloom_power))
		var crest: float = exp(-pow((t - crest_position) / maxf(crest_span, 0.001), 2.0))
		var profile: float = stream + crest * crest_strength
		profile *= 1.0 - smoothstep(tip_start, 1.0, t)
		for side: int in range(body_sides + 1):
			var u: float = float(side) / float(body_sides)
			var angle: float = u * TAU
			vertices.append(Vector3(cos(angle) * profile * 0.5, sin(angle) * profile * 0.5, t))
			normals.append(Vector3(cos(angle), sin(angle), 0.0))
			uvs.append(Vector2(u, t))
	for ring: int in range(body_rings):
		for side: int in range(body_sides):
			var a: int = ring * (body_sides + 1) + side
			var b: int = a + body_sides + 1
			indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_body.mesh = mesh
