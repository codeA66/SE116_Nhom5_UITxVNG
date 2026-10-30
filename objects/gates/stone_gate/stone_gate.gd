@tool
class_name StoneGate
extends StaticBody3D
## Cổng đá: chìm xuống đất khi TẤT CẢ nguồn kích hoạt gán ở ô Sources đã bật.
## Nguồn là node bất kỳ có signal "activated" và hàm is_active() (ổ đá, sau này thêm loại khác không sửa file này).
## Chỉ nghe đúng các nguồn được gán, nên map có nhiều cổng không ảnh hưởng nhau.
## Mở một lần rồi giữ nguyên; có persistent_id thì nhớ qua lần chơi sau.

signal opened
signal closed
## Vừa đủ nguồn, đang chờ wait_source báo mới chìm (camera cắt cảnh nghe signal này để bay tới)
signal unlock_started

@export var sources: Array[Node] = []:
	set(value):
		sources = value
		update_configuration_warnings()
## Cờ lưu trạng thái đã mở. Để trống = mỗi lần vào khu cổng lại đóng
@export var persistent_id: StringName
@export_range(0.1, 5.0, 0.05) var open_time: float = 1.2
## Cổng chìm xuống bấy nhiêu mét (thường bằng chiều cao cổng)
@export var sink_depth: float = 3.2
@export_range(0.0, 1.0) var open_trauma: float = 0.2

@export_group("Wait")
## Đủ nguồn thì chờ signal wait_signal (không tham số) của node này rồi mới chìm, ví dụ camera cắt cảnh đã tới khung hình.
## Để trống = chìm ngay
@export var wait_source: Node
@export var wait_signal: StringName = &"shot_reached"
## Quá thời gian này (giây) mà chưa có tín hiệu thì vẫn chìm: không để cổng kẹt vĩnh viễn
@export_range(0.5, 10.0, 0.1) var wait_timeout: float = 3.0

@export_group("Feedback")
## Đèn bừng sáng lúc bắt đầu chìm rồi tắt dần theo cổng: người chơi biết chính cổng này vừa được mở. Để trống = bỏ qua
@export var flash_light: Light3D
@export var flash_energy: float = 6.0
## Bụi phụt ở chân cổng lúc chìm (one shot). Để trống = bỏ qua
@export var dust: GPUParticles3D
## Tiếng đá ầm khi chìm; chưa gán stream thì im lặng
@export var open_sound: AudioStreamPlayer3D

@export_group("Pressure Plate")
@export var pressure_mode: bool = false
@export var pressed_color: Color = Color("3fe0d0")
@export var released_color: Color = Color("e64b50")
@export_range(0.0, 4.0, 0.1) var status_energy: float = 1.2
@export_range(0.0, 1.0, 0.01) var close_trauma: float = 0.12
@export_range(1, 64, 1) var pressure_dust_amount: int = 24
@export_range(-40.0, 0.0, 1.0) var pressure_sound_db: float = -14.0
## Có thể gán âm thanh riêng; để trống dùng tiếng ma sát/va đập tổng hợp sẵn trong bộ nhớ.
@export var pressure_open_audio: AudioStream
@export var pressure_close_audio: AudioStream

var is_open: bool = false
var _sinking: bool = false
var _closed_position: Vector3
var _pressure_tween: Tween
var _light_tween: Tween
var _status_materials: Array[StandardMaterial3D] = []

@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_closed_position = _visual.position
	if pressure_mode:
		_prepare_pressure_feedback()
		_pressure_color(false)
	if not pressure_mode and not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_finish_open(true)
		return
	for source in sources:
		if source == null or not source.has_signal(&"activated") or not source.has_method(&"is_active"):
			push_error("%s: nguồn %s không có signal activated / hàm is_active()" % [get_path(), source])
			continue
		source.connect(&"activated", _refresh)
		if pressure_mode and source.has_signal(&"deactivated"):
			source.connect(&"deactivated", _refresh)
	_refresh()


func _get_configuration_warnings() -> PackedStringArray:
	if sources.is_empty():
		return ["Chưa gán nguồn ở ô Sources: cổng sẽ không bao giờ mở."]
	return []


func _refresh() -> void:
	if pressure_mode:
		var pressed: bool = not sources.is_empty()
		for source in sources:
			if not is_instance_valid(source) or not source.has_method(&"is_active") or not source.call(&"is_active"):
				pressed = false
				break
		_set_pressure_open(pressed)
		return
	if is_open or sources.is_empty():
		return
	for source in sources:
		if source == null or not source.call(&"is_active"):
			return
	is_open = true
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	if wait_source == null or not wait_source.has_signal(wait_signal):
		_sink()
		return
	wait_source.connect(wait_signal, _sink, CONNECT_ONE_SHOT)
	get_tree().create_timer(wait_timeout).timeout.connect(_sink)
	unlock_started.emit()


## Chìm đúng một lần dù tín hiệu chờ và hết giờ cùng gọi
func _sink() -> void:
	if _sinking:
		return
	_sinking = true
	if open_trauma > 0.0:
		ScreenShake.add_trauma(open_trauma)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_visual, "position:y", _visual.position.y - sink_depth, open_time)
	tween.finished.connect(_finish_open.bind(false))
	if flash_light:
		var flash := create_tween()
		flash.tween_property(flash_light, "light_energy", flash_energy, 0.15)
		flash.tween_property(flash_light, "light_energy", 0.0, open_time)
	if dust:
		dust.restart()
	if open_sound and open_sound.stream:
		open_sound.play()
	# Mở lối ngay khi bắt đầu chìm: không bắt người chơi đứng chờ hết animation
	_collision.set_deferred(&"disabled", true)
	opened.emit()


func _finish_open(instant: bool) -> void:
	is_open = true
	_collision.set_deferred(&"disabled", true)
	if instant:
		_visual.position.y -= sink_depth
	_visual.visible = false


func _set_pressure_open(pressed: bool) -> void:
	if pressed == is_open:
		return
	is_open = pressed
	if _pressure_tween:
		_pressure_tween.kill()
	_visual.visible = true
	_pressure_color(pressed)
	# Collider đổi trong lượt deferred an toàn của physics, không chờ tween/vệt sáng.
	_collision.set_deferred(&"disabled", pressed)
	if pressed:
		_pressure_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pressure_tween.tween_property(_visual, "position:y", _closed_position.y - sink_depth, open_time)
		_pressure_tween.finished.connect(_finish_pressure_open)
		opened.emit()
	else:
		_visual.position = _closed_position
		closed.emit()
	_pressure_feedback(pressed)


func _finish_pressure_open() -> void:
	if is_open:
		_visual.visible = false


func _prepare_pressure_feedback() -> void:
	# Chỉ sao chép material phát sáng; phần đá và các cổng khác vẫn dùng material gốc.
	for child in _visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var original: StandardMaterial3D = mesh_instance.get_active_material(surface) as StandardMaterial3D
			if original == null or not original.emission_enabled:
				continue
			var material: StandardMaterial3D = original.duplicate() as StandardMaterial3D
			material.vertex_color_use_as_albedo = false
			if mesh_instance.material_override:
				mesh_instance.material_override = material
			else:
				mesh_instance.set_surface_override_material(surface, material)
			_status_materials.append(material)
	if dust:
		dust.amount = pressure_dust_amount
	if open_sound:
		open_sound.max_polyphony = 1
		open_sound.volume_db = pressure_sound_db
		if pressure_open_audio == null:
			pressure_open_audio = open_sound.stream if open_sound.stream else _stone_audio(false)
		if pressure_close_audio == null:
			pressure_close_audio = _stone_audio(true)


func _pressure_color(pressed: bool) -> void:
	var color: Color = pressed_color if pressed else released_color
	for material in _status_materials:
		material.albedo_color = color
		material.emission = color
		material.emission_energy_multiplier = status_energy
	if flash_light:
		flash_light.light_color = color
		flash_light.light_energy = status_energy


func _pressure_feedback(pressed: bool) -> void:
	# Phòng đang bị gỡ (chết, hồi sinh, đổi khu): đá rời ổ làm cổng "đóng" nhưng cổng đã ra khỏi cây,
	# không phát được tiếng / tween nữa. Trạng thái cổng vẫn đổi bình thường, chỉ bỏ hiệu ứng
	if not is_inside_tree():
		return
	ScreenShake.add_trauma(open_trauma if pressed else close_trauma)
	if dust:
		dust.restart()
	if open_sound:
		open_sound.stop()
		open_sound.stream = pressure_open_audio if pressed else pressure_close_audio
		open_sound.play()
	if _light_tween:
		_light_tween.kill()
	if flash_light:
		flash_light.light_energy = flash_energy
		_light_tween = create_tween()
		_light_tween.tween_property(flash_light, "light_energy", status_energy, 0.22)


func _stone_audio(impact: bool) -> AudioStreamWAV:
	# Tạo một lần khi vào scene; không cấp phát waveform mỗi lần đạp.
	var sample_rate: int = 16000
	var duration: float = 0.28 if impact else 0.75
	var samples: int = int(duration * sample_rate)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples * 2)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 7026 if impact else 7025
	var low_noise: float = 0.0
	for i in samples:
		var t: float = float(i) / sample_rate
		low_noise = lerpf(low_noise, random.randf_range(-1.0, 1.0), 0.16)
		var envelope: float = exp(-t * 17.0) if impact else sin(PI * t / duration)
		var tone: float = sin(TAU * (62.0 if impact else 43.0) * t)
		var value: int = int(clampf((low_noise * 0.75 + tone * 0.25) * envelope, -1.0, 1.0) * 28000.0)
		bytes[i * 2] = value & 255
		bytes[i * 2 + 1] = (value >> 8) & 255
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	return stream
