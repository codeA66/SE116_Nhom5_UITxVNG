class_name LaserEmitter
extends Node3D
## Tượng bắn laser (kiểu Death's Door): tia đỏ bắn thẳng theo -Z của node, dừng ở tường (layer world),
## bật / tắt theo nhịp LaserTiming, có tia báo trước mờ trước khi bật. Chạm tia đang bật mất máu qua DamageArea.
## Lộn (dash) đi qua được vì dash có bất tử. Không hại quái (DamageArea chỉ quét layer của player).
## Hiệu năng: đổi pha bằng Timer, không có _process; độ dài tia chỉ đo một lần mỗi chu kỳ (lúc báo trước) vì tường đứng yên.

signal activated
signal deactivated
signal vfx_phase_changed(next: Phase, remaining: float, full_duration: float, ray_length: float,
	wall_normal: Vector3, width: float, blink_rate: float, offset: float)

enum Phase { OFF, WARN, ON }

@export var timing: LaserTiming
## Lệch pha so với tượng khác (giây): các tượng cùng nhịp nhưng tắt / bật so le để tạo đường né
@export var phase_offset: float = 0.0
## Bề ngang tia gây sát thương (m); hình tia lấy theo đây
@export_range(0.05, 3.0, 0.01) var beam_width: float = 0.22
## Nhấp nháy của tia báo trước (lần / giây)
@export_range(0.0, 30.0, 0.5) var warn_blink_rate: float = 10.0

var phase: Phase = Phase.OFF

var _length: float = 0.0
var _wall_normal: Vector3 = Vector3.ZERO

@onready var _muzzle: Node3D = $Muzzle
@onready var _ray: RayCast3D = $Muzzle/Ray
@onready var _damage: DamageArea = $Muzzle/DamageArea
@onready var _damage_shape: CollisionShape3D = $Muzzle/DamageArea/CollisionShape3D
@onready var _timer: Timer = $PhaseTimer
@onready var _on_sound: AudioStreamPlayer3D = $OnSound


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if timing == null:
		push_warning("%s thiếu LaserTiming: tượng không bắn" % get_path())
		_damage.set_active(false)
		return
	_ray.enabled = false
	_ray.target_position = Vector3(0.0, 0.0, -timing.max_range)
	_timer.one_shot = true
	_timer.timeout.connect(_advance)
	_damage.set_active(false)
	# Đợi vật lý dựng xong tường mới đo tia
	await get_tree().physics_frame
	_start_at(fposmod(phase_offset, maxf(timing.cycle_length(), 0.001)))


## Tia đang gây sát thương
func is_active() -> bool:
	return phase == Phase.ON


## Bắt đầu chu kỳ ở thời điểm t (giây tính từ đầu pha bật)
func _start_at(t: float) -> void:
	var warn_start := timing.on_time + timing.off_time - timing.warn_time
	if t < timing.on_time:
		_enter(Phase.ON, timing.on_time - t)
	elif t < warn_start:
		_enter(Phase.OFF, warn_start - t)
	else:
		_enter(Phase.WARN, timing.on_time + timing.off_time - t)


func _advance() -> void:
	match phase:
		Phase.ON:
			if timing.off_time - timing.warn_time > 0.0:
				_enter(Phase.OFF, timing.off_time - timing.warn_time)
			else:
				_enter(Phase.WARN, timing.warn_time)
		Phase.OFF:
			_enter(Phase.WARN, timing.warn_time)
		Phase.WARN:
			_enter(Phase.ON, timing.on_time)


func _enter(next: Phase, duration: float) -> void:
	phase = next
	if next == Phase.WARN or (next == Phase.ON and _length <= 0.0):
		_measure()
	_damage.set_active(next == Phase.ON)
	if next == Phase.ON:
		if _on_sound.stream:
			_on_sound.play()
		activated.emit()
	elif next == Phase.OFF:
		deactivated.emit()
	var full_duration: float = timing.on_time
	if next == Phase.WARN:
		full_duration = timing.warn_time
	elif next == Phase.OFF:
		full_duration = timing.off_time - timing.warn_time
	vfx_phase_changed.emit(next, duration, full_duration, _length, _wall_normal, beam_width,
		warn_blink_rate, phase_offset)
	if duration <= 0.0:
		# Pha dài 0 (vd. warn_time = 0): sang pha kế ngay, không đợi khung sau
		_advance.call_deferred()
		return
	_timer.start(duration)


## Đo tia tới tường gần nhất để vùng sát thương và VFX dùng cùng một điểm kết thúc.
func _measure() -> void:
	# Truy vấn thẳng một lần, không giữ RayCast3D bật (bật thì engine dò mỗi khung vật lý dù không ai đọc)
	var from := _muzzle.global_position
	var query := PhysicsRayQueryParameters3D.create(from, _muzzle.to_global(_ray.target_position), _ray.collision_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_length = from.distance_to(hit.position) if not hit.is_empty() else timing.max_range
	_length = maxf(_length, 0.05)
	_wall_normal = Vector3.ZERO
	if not hit.is_empty():
		var normal: Vector3 = hit.normal
		_wall_normal = (_muzzle.global_basis.transposed() * normal).normalized()
	(_damage_shape.shape as BoxShape3D).size = Vector3(beam_width, beam_width * 2.0, _length)
	_damage_shape.position = Vector3(0.0, 0.0, -_length * 0.5)
