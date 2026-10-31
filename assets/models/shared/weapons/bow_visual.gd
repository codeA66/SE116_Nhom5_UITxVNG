@tool
class_name BowVisual
extends Node3D
## Cung dùng model import (golden_bow.glb). Dây là 2 mesh trụ dài 1 m dọc trục Y, gốc ở giữa, đặt sẵn ở tư thế nghỉ:
## điểm móc dây đọc từ tư thế đó nên đổi model khác không phải sửa code. Kéo dây thì dây và rune sáng dần.
## Khi đang nhắm (set_aiming): hiện mũi tên trên dây, bật đèn và hạt sáng, mạnh dần theo độ kéo.
## Cung nằm trên đất (vật phẩm nhặt) không nhắm nên không có đèn / hạt / mũi tên.

@export_range(0.0, 1.0) var draw_amount: float = 0.0:
	set(value):
		draw_amount = clampf(value, 0.0, 1.0)
		if is_node_ready():
			_update_draw()
## Đoạn dây trên: đầu +Y của mesh là điểm móc
@export var string_top_path: NodePath
## Đoạn dây dưới: đầu -Y của mesh là điểm móc
@export var string_bottom_path: NodePath
## Mesh sáng dần theo độ kéo (dây, rune); chỉ đổi surface 0
@export var glow_mesh_paths: Array[NodePath] = []

@export_group("Draw")
## Quãng kéo điểm giữa dây ra sau (m, theo toạ độ của node này, đã tính scale của model)
@export_range(0.0, 1.0, 0.01, "or_greater") var draw_distance: float = 0.24:
	set(value):
		draw_distance = maxf(value, 0.0)
		if is_node_ready():
			_cache_pull_offset()
			_update_draw()

@export_group("Glow")
## Hệ số nhân độ sáng gốc của material lúc nghỉ và lúc kéo đầy
@export_range(0.0, 4.0, 0.05, "or_greater") var rest_glow: float = 0.4
@export_range(0.0, 4.0, 0.05, "or_greater") var full_glow: float = 1.5

@export_group("Aim Effects")
## Mũi tên đặt trên dây khi nhắm; gốc node là chỗ khấc tên, đi theo tâm dây
@export var nocked_arrow_path: NodePath
## Đèn sáng dần theo độ kéo (tắt khi chưa kéo)
@export var light_path: NodePath
@export_range(0.0, 16.0, 0.1, "or_greater") var full_light_energy: float = 2.5
## Hạt dọc dây: đặt giữa tâm dây và đường nối hai điểm móc
@export var string_particles_path: NodePath
## Các hệ hạt bật khi nhắm, lượng hạt tỉ lệ độ kéo
@export var aim_particle_paths: Array[NodePath] = []

@export_group("Charge")
## Cụm tụ lực đặt phía trước cung trên đường bắn (vị trí chỉnh ở node này trong scene)
@export var charge_fx_path: NodePath
## Ngôi sao 4 cánh ở tâm: to và sáng dần theo độ kéo, xoay chậm, kéo đầy thì nhói một nhịp (báo "đủ lực")
@export var charge_star_path: NodePath
## Các vòng vàng co dần từ to về ngôi sao, lặp liên tục khi đang giữ; mỗi vòng lệch pha đều nhau
@export var charge_ring_paths: Array[NodePath] = []
## Hạt tụ lực (tia hút vào, bụi vàng): bật khi đang kéo, sáng theo độ kéo
@export var charge_particle_paths: Array[NodePath] = []
## Vệt sáng dọc thân mũi tên trên dây, sáng dần theo độ kéo
@export var arrow_glow_path: NodePath
## Cạnh quad ngôi sao khi kéo đầy (m)
@export_range(0.0, 2.0, 0.01, "or_greater") var star_size: float = 0.35
@export_range(1.0, 3.0, 0.05) var star_pulse_scale: float = 1.3
@export_range(0.01, 1.0, 0.01, "or_greater") var star_pulse_time: float = 0.17
## Tốc độ xoay ngôi sao (rad/s)
@export_range(0.0, 10.0, 0.05, "or_greater") var star_spin_speed: float = 0.6
## Cỡ vòng lúc mới xuất hiện (cạnh quad, m) và thời gian co về tâm (s)
@export_range(0.0, 10.0, 0.05, "or_greater") var ring_start_size: float = 2.0
@export_range(0.05, 5.0, 0.01, "or_greater") var ring_period: float = 0.7
@export_range(0.0, 10.0, 0.1, "or_greater") var ring_intensity: float = 1.6
@export_range(0.0, 10.0, 0.1, "or_greater") var arrow_glow_intensity: float = 3.0
## Độ kéo tối thiểu để bật hạt tụ lực
@export_range(0.0, 1.0, 0.01) var charge_particle_threshold: float = 0.15

@export_group("Release Flash")
## Đĩa sáng tại dây lúc buông
@export var muzzle_flash_path: NodePath
@export_range(0.0, 3.0, 0.01, "or_greater") var flash_size: float = 0.45
@export_range(0.01, 1.0, 0.01, "or_greater") var flash_time: float = 0.1

@export_group("Sound")
## Âm thanh kéo dây / buông dây; để trống = im lặng (chỗ cắm sẵn)
@export var draw_sound: AudioStream
@export var release_sound: AudioStream
@export var draw_sound_path: NodePath
@export var release_sound_path: NodePath

var _top_string: Node3D
var _bottom_string: Node3D
## Điểm móc và tâm dây nghỉ, tính trong hệ toạ độ của cha hai đoạn dây
var _top_nock: Vector3
var _bottom_nock: Vector3
var _rest_center: Vector3
## Hướng "ra sau" và quãng kéo quy về hệ toạ độ của cha hai đoạn dây
var _pull_offset: Vector3
## Tâm dây nghỉ trong hệ toạ độ của node này (cho mũi tên, hạt)
var _rest_center_local: Vector3
var _glow_materials: Array[BaseMaterial3D] = []
var _glow_base_energy: PackedFloat32Array = PackedFloat32Array()
var _aiming: bool = false
var _nocked_arrow: Node3D
var _light: Light3D
var _string_particles: Node3D
var _aim_particles: Array[GPUParticles3D] = []
var _charge_fx: Node3D
var _star: Node3D
var _star_material: ShaderMaterial
var _star_base_intensity: float = 1.0
var _rings: Array[Node3D] = []
var _ring_materials: Array[ShaderMaterial] = []
var _charge_particles: Array[CPUParticles3D] = []
var _particle_materials: Array[ShaderMaterial] = []
var _particle_base_intensity: PackedFloat32Array = PackedFloat32Array()
var _arrow_glow_material: ShaderMaterial
var _flash: Node3D
var _draw_player: AudioStreamPlayer3D
var _release_player: AudioStreamPlayer3D
## Thời gian đã giữ cung (nhịp vòng co, xoay sao)
var _charge_time: float = 0.0
## > 0: ngôi sao đang nhói (giây còn lại); _pulsed: đã nhói ở lần kéo đầy này
var _pulse_left: float = 0.0
var _pulsed: bool = false
var _flash_left: float = 0.0


func _ready() -> void:
	# Chỉ chạy _process khi đang nhắm hoặc đang chớp sáng
	set_process(false)
	_top_string = get_node_or_null(string_top_path) as Node3D
	_bottom_string = get_node_or_null(string_bottom_path) as Node3D
	if _top_string == null or _bottom_string == null:
		push_warning("BowVisual: thiếu node dây cung")
		return
	_top_nock = _top_string.position + _top_string.basis.y * 0.5
	_bottom_nock = _bottom_string.position - _bottom_string.basis.y * 0.5
	_rest_center = (_top_nock + _bottom_nock) * 0.5
	_rest_center_local = _relative_transform(_top_string.get_parent()) * _rest_center
	_top_string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bottom_string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nocked_arrow = get_node_or_null(nocked_arrow_path) as Node3D
	_light = get_node_or_null(light_path) as Light3D
	_string_particles = get_node_or_null(string_particles_path) as Node3D
	for path in aim_particle_paths:
		var particles := get_node_or_null(path) as GPUParticles3D
		if particles:
			_aim_particles.append(particles)
	_charge_fx = get_node_or_null(charge_fx_path) as Node3D
	_star = get_node_or_null(charge_star_path) as Node3D
	if _star is GeometryInstance3D:
		_star_material = (_star as GeometryInstance3D).material_override as ShaderMaterial
		if _star_material:
			_star_base_intensity = float(_star_material.get_shader_parameter(&"intensity"))
	for path in charge_ring_paths:
		var ring := get_node_or_null(path) as GeometryInstance3D
		if ring and ring.material_override is ShaderMaterial:
			_rings.append(ring)
			_ring_materials.append(ring.material_override as ShaderMaterial)
	for path in charge_particle_paths:
		var particles := get_node_or_null(path) as CPUParticles3D
		if particles and particles.material_override is ShaderMaterial:
			var material := particles.material_override as ShaderMaterial
			_charge_particles.append(particles)
			_particle_materials.append(material)
			_particle_base_intensity.append(float(material.get_shader_parameter(&"intensity")))
	var arrow_glow := get_node_or_null(arrow_glow_path) as GeometryInstance3D
	if arrow_glow:
		_arrow_glow_material = arrow_glow.material_override as ShaderMaterial
	_flash = get_node_or_null(muzzle_flash_path) as Node3D
	_draw_player = get_node_or_null(draw_sound_path) as AudioStreamPlayer3D
	_release_player = get_node_or_null(release_sound_path) as AudioStreamPlayer3D
	if _draw_player:
		_draw_player.stream = draw_sound
	if _release_player:
		_release_player.stream = release_sound
	if _flash:
		_flash.position = _rest_center_local
	_cache_pull_offset()
	# Trong editor không đụng vào model khi mở scene, để không sinh thuộc tính ghi đè vào .tscn
	if Engine.is_editor_hint():
		return
	_setup_glow_materials()
	set_aiming(false)
	_update_draw()


## Bật / tắt mũi tên trên dây, đèn và hạt (Player gọi khi bắt đầu / thôi nhắm)
## false: không bật cụm tụ lực mặc định (sao, vòng, tia) khi nhắm, vì cung đang ghép nguyên tố có VFX tụ lực riêng
## (lửa, gió...) thay thế. Dây sáng, mũi tên trên dây, chớp lúc buông vẫn giữ. Player đặt trước mỗi lần nhắm
var default_charge_enabled: bool = true


func set_aiming(on: bool) -> void:
	_aiming = on
	if _nocked_arrow:
		_nocked_arrow.visible = on
	if _light:
		_light.visible = on
	for particles in _aim_particles:
		particles.emitting = on
		particles.visible = on
	_set_charge_active(on and default_charge_enabled)
	_charge_time = 0.0
	_pulsed = false
	_pulse_left = 0.0
	if on and _draw_player and _draw_player.stream:
		_draw_player.play()
	_update_process()
	_update_draw()


func _process(delta: float) -> void:
	if _aiming:
		_charge_time += delta
	if _pulse_left > 0.0:
		_pulse_left = maxf(_pulse_left - delta, 0.0)
	if _aiming:
		_update_charge()
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		_update_flash()
	_update_process()


## Chớp sáng tại dây lúc buông; mũi tên trên dây và cụm tụ lực tắt luôn (mũi tên thật đã bay đi)
func play_release_flash() -> void:
	if _nocked_arrow:
		_nocked_arrow.visible = false
	_set_charge_active(false)
	if _release_player and _release_player.stream:
		_release_player.play()
	if _flash == null:
		return
	_flash_left = flash_time
	_flash.visible = true
	_update_flash()
	_update_process()


func _update_process() -> void:
	set_process(_aiming or _flash_left > 0.0)


func _set_charge_active(on: bool) -> void:
	if _charge_fx:
		_charge_fx.visible = on
	for particles in _charge_particles:
		particles.emitting = false
	if _arrow_glow_material:
		_arrow_glow_material.set_shader_parameter(&"intensity", 0.0)


## Cụm tụ lực theo video tham khảo: sao 4 cánh trước cung, vòng vàng co dần vào sao (lặp),
## tia sáng hút vào, bụi vàng lơ lửng, mũi tên sáng dần. Độ mạnh theo độ kéo
func _update_charge() -> void:
	if _charge_fx == null or not _charge_fx.visible:
		return
	var k := smoothstep(0.0, 1.0, draw_amount)
	if _star:
		var pulse := 1.0
		if _pulse_left > 0.0:
			# Phồng lên rồi xẹp về trong star_pulse_time
			pulse = 1.0 + (star_pulse_scale - 1.0) * sin(PI * (1.0 - _pulse_left / star_pulse_time))
		_star.scale = Vector3.ONE * maxf(star_size * lerpf(0.3, 1.0, k) * pulse, 0.0001)
		if _star_material:
			_star_material.set_shader_parameter(&"intensity", _star_base_intensity * lerpf(0.3, 1.0, k))
			_star_material.set_shader_parameter(&"spin", _charge_time * star_spin_speed)
	var ring_count := _rings.size()
	# Vòng luôn quay mặt về camera (như video): PlaneMesh có pháp tuyến +Y, xoay +Y về phía camera
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	var camera := get_viewport().get_camera_3d()
	if camera and _charge_fx:
		var to_camera := camera.global_position - _charge_fx.global_position
		if to_camera.length_squared() > 0.0001:
			var y_axis := to_camera.normalized()
			var x_axis := y_axis.cross(Vector3.UP)
			if x_axis.length_squared() < 0.0001:
				x_axis = Vector3.RIGHT
			x_axis = x_axis.normalized()
			facing = Basis(x_axis, y_axis, x_axis.cross(y_axis))
	for index in ring_count:
		# Mỗi vòng lệch pha đều nhau; phase 0 = to nhất (mới hiện), 1 = co về tâm
		var phase := fmod(_charge_time / ring_period + float(index) / float(ring_count), 1.0)
		var size := maxf(ring_start_size * (1.0 - phase), 0.0001)
		_rings[index].global_basis = facing.scaled(Vector3.ONE * size)
		# Hiện dần lúc mới xuất hiện, tắt dần khi chạm tâm
		_ring_materials[index].set_shader_parameter(&"intensity", ring_intensity * k * sin(PI * phase))
	var particles_on := draw_amount >= charge_particle_threshold
	for index in _charge_particles.size():
		var particles := _charge_particles[index]
		if particles.emitting != particles_on:
			particles.emitting = particles_on
		_particle_materials[index].set_shader_parameter(&"intensity", _particle_base_intensity[index] * k)
	if _arrow_glow_material:
		_arrow_glow_material.set_shader_parameter(&"intensity", arrow_glow_intensity * k)


func _update_flash() -> void:
	var t := 1.0 - _flash_left / flash_time
	# Bung nhanh tới cỡ tối đa ở 1/3 thời gian rồi co về 0
	var size := t / 0.33 if t < 0.33 else (1.0 - t) / 0.67
	_flash.scale = Vector3.ONE * maxf(flash_size * size, 0.0001)
	_flash.visible = _flash_left > 0.0


func _cache_pull_offset() -> void:
	if _top_string == null:
		return
	var to_parent := _relative_transform(_top_string.get_parent()).affine_inverse()
	_pull_offset = to_parent.basis * Vector3(0.0, 0.0, -draw_distance)


## Biến đổi của node so với node này (không dùng global_transform để chạy được cả khi chưa vào tree)
func _relative_transform(node: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current := node
	while current and current != self:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func _setup_glow_materials() -> void:
	# Mỗi cung một bản material riêng vì độ sáng đổi theo cung; nhiều mesh dùng chung material thì vẫn chung bản sao
	var copies := {}
	for path in glow_mesh_paths:
		var mesh := get_node_or_null(path) as MeshInstance3D
		if mesh == null:
			push_warning("BowVisual: không thấy mesh phát sáng %s" % path)
			continue
		var source := mesh.get_active_material(0) as BaseMaterial3D
		if source == null:
			continue
		if not copies.has(source):
			var copy := source.duplicate() as BaseMaterial3D
			copies[source] = copy
			_glow_materials.append(copy)
			_glow_base_energy.append(source.emission_energy_multiplier)
		mesh.set_surface_override_material(0, copies[source])


func _update_draw() -> void:
	if _top_string == null or _bottom_string == null:
		return
	var center := _rest_center + _pull_offset * draw_amount
	_place_rod(_top_string, center, _top_nock)
	_place_rod(_bottom_string, _bottom_nock, center)
	var glow := lerpf(rest_glow, full_glow, draw_amount)
	for index in _glow_materials.size():
		_glow_materials[index].emission_energy_multiplier = _glow_base_energy[index] * glow
	if not _aiming:
		return
	var center_local := _rest_center_local + Vector3(0.0, 0.0, -draw_distance * draw_amount)
	if _nocked_arrow:
		_nocked_arrow.position = center_local
	if _string_particles:
		_string_particles.position = (center_local + _rest_center_local) * 0.5
	if _light:
		_light.light_energy = full_light_energy * draw_amount
	for particles in _aim_particles:
		particles.amount_ratio = draw_amount
	# Vừa kéo đầy: ngôi sao nhói một nhịp (mỗi lần kéo chỉ một lần)
	if draw_amount >= 0.999:
		if not _pulsed:
			_pulsed = true
			_pulse_left = star_pulse_time
	else:
		_pulsed = false
	_update_charge()


func _place_rod(node: Node3D, start: Vector3, end: Vector3) -> void:
	var direction := end - start
	node.position = (start + end) * 0.5
	node.quaternion = Quaternion(Vector3.UP, direction.normalized())
	node.scale = Vector3(1.0, direction.length(), 1.0)
