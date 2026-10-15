@tool
class_name WindZone
extends Area3D
## Vùng gió: đẩy mọi WindReceiverComponent bên trong theo trục -Z cục bộ.
## Xoay node để đổi hướng: luồng ngang và cột gió nâng là cùng một component.

signal active_changed(active: bool)

## Vùng có hướng gió lệch khỏi phương ngang quá mức này được coi là cột gió (lên hoặc xuống)
const VERTICAL_THRESHOLD := 0.7
## Vòng sáng: độ sáng thấp nhất trong nhịp nhấp nháy, và hệ số khi gió đang tắt
const RING_PULSE_MIN := 0.7
const RING_INACTIVE_FACTOR := 0.25
## Vòng sáng rộng hơn tiết diện cột một chút để dễ thấy
const RING_SIZE_FACTOR := 1.3
## Nhích vòng sáng khỏi mặt đất để không bị nhấp nháy (z-fighting)
const RING_SURFACE_OFFSET := 0.05

@export var data: WindData:
	set(value):
		data = value
		update_configuration_warnings()
## Kích thước vùng (cục bộ); chiều Z là chiều gió thổi
@export var size: Vector3 = Vector3(4.0, 3.0, 8.0):
	set(value):
		size = value
		if is_node_ready():
			_apply_size()
## Lực giảm dần về 0 ở cuối vùng: dùng cho cột gió để nhân vật lơ lửng gần đỉnh
@export var fade_toward_end: bool = false

var active: bool = true

var _cycle_time: float = 0.0
var _ring_material: StandardMaterial3D
var _visual_time: float = 0.0

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _particles: CPUParticles3D = $Particles
@onready var _base_ring: MeshInstance3D = $BaseRing


func _ready() -> void:
	monitoring = false
	monitorable = true
	_apply_size()
	if Engine.is_editor_hint():
		return
	if data == null:
		# Không dừng game vì một vùng cấu hình sai: báo lỗi và tắt vùng này
		push_error("%s chưa gán WindData, vùng gió bị tắt" % get_path())
		_set_active(false)
		return
	_setup_particles()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or data == null or not data.pulse_enabled:
		return
	_cycle_time = fmod(_cycle_time + delta, data.on_time + data.off_time)
	_set_active(_cycle_time < data.on_time)
	# Báo hiệu: hạt bay chậm xuất hiện trước khi gió bật lại
	var warning := not active and _cycle_time >= data.on_time + data.off_time - data.warning_time
	_particles.emitting = active or warning
	_particles.speed_scale = 1.0 if active else 0.35


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _base_ring.visible:
		return
	_visual_time += delta
	# Vòng sáng nhấp nháy nhẹ; gió tắt (ngắt quãng) thì mờ hẳn
	var pulse := lerpf(RING_PULSE_MIN, 1.0, 0.5 + 0.5 * sin(_visual_time * data.ring_pulse_speed))
	_ring_material.albedo_color.a = data.ring_opacity * pulse * (1.0 if active else RING_INACTIVE_FACTOR)


func _get_configuration_warnings() -> PackedStringArray:
	if data == null:
		return ["Chưa gán WindData: kéo một file trong resources/wind/ vào ô Data."]
	return []


## Gió thổi gần thẳng đứng (cột gió nâng hoặc hút xuống)
func is_vertical() -> bool:
	return absf(-global_basis.z.normalized().y) >= VERTICAL_THRESHOLD


## Lực gió tại một điểm trong vùng (vận tốc, m/s)
func get_wind_at(world_position: Vector3) -> Vector3:
	if not active or data == null:
		return Vector3.ZERO
	var strength := data.strength
	if fade_toward_end:
		# Tiến độ dọc theo chiều gió: 0 ở đầu vùng, 1 ở cuối vùng
		var progress := clampf((size.z * 0.5 - to_local(world_position).z) / size.z, 0.0, 1.0)
		strength *= 1.0 - progress
	return -global_basis.z.normalized() * strength


func _set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	active_changed.emit(active)


func _apply_size() -> void:
	# Shape đánh dấu local_to_scene nên mỗi vật có bản riêng: chỉ đổi kích thước, không tạo shape mới
	# (tạo mới sẽ làm editor ghi thêm shape thừa vào scene cha khi lưu)
	(_shape.shape as BoxShape3D).size = size


func _setup_particles() -> void:
	var vertical := is_vertical()
	var material := ((_particles.mesh as PrimitiveMesh).material as StandardMaterial3D).duplicate() as StandardMaterial3D
	material.albedo_color = data.updraft_color if vertical else data.particle_color
	# Màu theo vòng đời hạt (color_ramp) nhân vào albedo để làm mờ dần
	material.vertex_color_use_as_albedo = true
	_particles.material_override = material
	_particles.color_ramp = _make_fade_ramp(vertical)

	# Hạt chỉ sinh ở mặt đầu vùng (+Z, gió thổi về -Z) và bay vừa hết chiều dài vùng:
	# chỗ nào thấy vệt gió thì chỗ đó có lực, không bị lố ra ngoài
	_particles.position = Vector3(0.0, 0.0, size.z * 0.5)
	_particles.emission_box_extents = Vector3(size.x * 0.5, size.y * 0.5, 0.0)
	_particles.amount = maxi(4, int(size.x * size.y * size.z * data.particle_density))
	var speed := maxf(data.strength * 2.0, 1.0)
	_particles.initial_velocity_min = speed * 0.8
	_particles.initial_velocity_max = speed * 1.2
	# Tính theo hạt nhanh nhất để không hạt nào bay quá cuối vùng
	_particles.lifetime = size.z / _particles.initial_velocity_max
	# Chạy trước một vòng đời để vùng gió đã đầy vệt ngay khi scene bắt đầu
	_particles.preprocess = _particles.lifetime
	_particles.emitting = true

	_setup_base_ring(vertical)


## Gió ngang: hiện dần ở đầu, mờ dần ở cuối. Cột gió: rõ ở chân, mờ dần khi lên cao
func _make_fade_ramp(vertical: bool) -> Gradient:
	var ramp := Gradient.new()
	if vertical:
		ramp.offsets = PackedFloat32Array([0.0, 0.1, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	else:
		ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return ramp


## Vòng sáng ở mặt đầu vùng (chân cột gió), chỉ hiện với cột gió
func _setup_base_ring(vertical: bool) -> void:
	_base_ring.visible = vertical
	if not vertical:
		return
	_ring_material = (_base_ring.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	_ring_material.albedo_color = data.updraft_color
	_base_ring.material_override = _ring_material
	_base_ring.position = Vector3(0.0, 0.0, size.z * 0.5 - RING_SURFACE_OFFSET)
	_base_ring.scale = Vector3(size.x * RING_SIZE_FACTOR, size.y * RING_SIZE_FACTOR, 1.0)
