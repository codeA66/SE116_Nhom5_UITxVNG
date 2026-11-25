class_name BowDrawFeedback
extends Node3D
## Báo độ kéo cung theo kiểu Death's Door: mọi tín hiệu nằm trên hướng bắn ngang tầm ngực, không vẽ gì dưới chân.
## - Đang kéo: mũi tên chỉ hướng màu lạnh, dài dần theo độ kéo, kèm vạch ngắm mảnh mờ phía trước.
## - Kéo đầy: đổi hẳn sang màu ấm (mũi tên + vạch), hiện vòng cung sáng trước ngực, đèn ấm hắt xuống sàn.
##   Đổi màu đột ngột chính là tín hiệu "thả là bắn".
## - Thả sớm (hủy): mũi tên xám rồi tắt + khói tối, báo phát này không bắn.
## - Chất riêng của game (cáo + gió): sợi gió lạnh tụ dần vào đầu mũi tên khi kéo; tia lửa ấm bật ra một nhịp khi đầy.
## Cỡ theo mét trong thế giới (đọc được ở camera 38 m), không phụ thuộc model cung nên cung ghép nguyên tố cũng có.
## Nghe signal của Player; chỉ chạy _process khi đang có gì hiện.

@export var player: Player

@export_group("Mũi tên chỉ hướng")
## Dài lúc mới kéo và lúc kéo đầy (m), bề ngang (m)
@export_range(0.1, 5.0, 0.05) var pointer_min_length: float = 0.55
@export_range(0.1, 6.0, 0.05) var pointer_length: float = 1.1
@export_range(0.05, 2.0, 0.01) var pointer_width: float = 0.6
## Mũi tên bắt đầu cách tay cầm cung bấy nhiêu mét về phía trước
@export_range(0.0, 2.0, 0.05) var pointer_offset: float = 0.25

@export_group("Vạch ngắm")
@export_range(0.0, 20.0, 0.1) var aim_line_length: float = 4.0
@export_range(0.01, 0.5, 0.01) var aim_line_width: float = 0.05

@export_group("Kéo đầy")
## Vòng cung trước ngực: bán kính (m) và nhịp bật ra lúc vừa đầy (s)
@export_range(0.1, 4.0, 0.05) var arc_size: float = 1.15
@export_range(0.01, 0.5, 0.01) var arc_pop_time: float = 0.12
## Đèn ấm hắt xuống sàn khi đầy
@export_range(0.0, 10.0, 0.1) var light_energy: float = 0.9

@export_group("Hủy / kết thúc")
@export_range(0.05, 1.0, 0.01) var cancel_time: float = 0.25
@export_range(0.01, 0.5, 0.01) var end_fade_time: float = 0.08

var _draw: float = 0.0
var _aiming: bool = false
var _ready_fired: bool = false
var _ready_clock: float = -1.0
var _fade_clock: float = -1.0
var _cancel_clock: float = -1.0

@onready var _pointer: MeshInstance3D = $Pointer
@onready var _aim_line: MeshInstance3D = $AimLine
@onready var _arc: MeshInstance3D = $ReadyArc
@onready var _light: OmniLight3D = $ReadyLight
@onready var _puff: CPUParticles3D = $CancelPuff
@onready var _wind: CPUParticles3D = $WindGather
@onready var _sparks: CPUParticles3D = $ReadySparks
@onready var _pointer_mat: ShaderMaterial = _pointer.material_override as ShaderMaterial
@onready var _line_mat: ShaderMaterial = _aim_line.material_override as ShaderMaterial
@onready var _arc_mat: ShaderMaterial = _arc.material_override as ShaderMaterial


func _ready() -> void:
	top_level = true
	_hide_all()
	if player == null:
		push_warning("%s: chưa gán player" % get_path())
		return
	player.bow_draw_progress.connect(_on_progress)
	player.bow_draw_cancelled.connect(_on_cancelled)


func _process(delta: float) -> void:
	var busy := _aiming or _puff.emitting or _sparks.emitting
	_place()
	if _ready_clock >= 0.0:
		_ready_clock += delta
		# Vòng cung bật to hơn một chút rồi về cỡ thường; đèn chớp rồi về mức giữ
		var t := clampf(_ready_clock / arc_pop_time, 0.0, 1.0)
		_arc.scale = Vector3.ONE * arc_size * lerpf(1.3, 1.0, t)
		_light.light_energy = light_energy * lerpf(2.0, 1.0, t)
		if t >= 1.0:
			_ready_clock = -1.0
		busy = true
	if _cancel_clock >= 0.0:
		_cancel_clock += delta
		var t := clampf(_cancel_clock / cancel_time, 0.0, 1.0)
		_pointer_mat.set_shader_parameter(&"opacity", 1.0 - t)
		if t >= 1.0:
			_cancel_clock = -1.0
			_pointer.hide()
		else:
			busy = true
	if _fade_clock >= 0.0:
		_fade_clock += delta
		var t := clampf(_fade_clock / end_fade_time, 0.0, 1.0)
		_pointer_mat.set_shader_parameter(&"opacity", 1.0 - t)
		_line_mat.set_shader_parameter(&"opacity", (1.0 - t) * 0.35)
		_arc_mat.set_shader_parameter(&"opacity", 1.0 - t)
		_light.light_energy = light_energy * (1.0 - t)
		if t >= 1.0:
			_fade_clock = -1.0
			_hide_layers()
		else:
			busy = true
	set_process(busy)


func _on_progress(amount: float) -> void:
	_draw = amount
	if amount > 0.0:
		if not _aiming:
			_start_aim()
		if amount >= 0.999 and not _ready_fired:
			_ready_fired = true
			_play_ready()
		return
	# Về 0: đã bắn hoặc thôi nhắm (hủy đã được báo riêng qua _on_cancelled trước đó)
	if _aiming:
		_aiming = false
		_wind.emitting = false
		if _cancel_clock < 0.0:
			_fade_clock = 0.0
		set_process(true)


func _on_cancelled() -> void:
	_aiming = false
	_ready_fired = false
	_fade_clock = -1.0
	_ready_clock = -1.0
	_wind.emitting = false
	_aim_line.hide()
	_arc.hide()
	_light.hide()
	_pointer_mat.set_shader_parameter(&"cancel", 1.0)
	_cancel_clock = 0.0
	_puff.global_position = _pointer.global_position
	_puff.restart()
	_puff.emitting = true
	set_process(true)


func _start_aim() -> void:
	_aiming = true
	_ready_fired = false
	_fade_clock = -1.0
	_cancel_clock = -1.0
	_ready_clock = -1.0
	_pointer_mat.set_shader_parameter(&"ready", 0.0)
	_pointer_mat.set_shader_parameter(&"cancel", 0.0)
	_pointer_mat.set_shader_parameter(&"opacity", 1.0)
	_line_mat.set_shader_parameter(&"ready", 0.0)
	_line_mat.set_shader_parameter(&"opacity", 0.35)
	_arc.hide()
	_light.hide()
	_pointer.show()
	_aim_line.show()
	_place()
	_wind.restart()
	_wind.emitting = true
	set_process(true)


func _play_ready() -> void:
	_pointer_mat.set_shader_parameter(&"ready", 1.0)
	_line_mat.set_shader_parameter(&"ready", 1.0)
	_arc_mat.set_shader_parameter(&"opacity", 1.0)
	_arc.show()
	_light.light_energy = light_energy * 2.0
	_light.show()
	_ready_clock = 0.0
	_place()
	# Gió đã tụ xong: tắt sợi gió, bật tia lửa ấm một nhịp
	_wind.emitting = false
	_sparks.restart()
	_sparks.emitting = true
	set_process(true)


## Đặt mũi tên, vạch ngắm, vòng cung theo tay cầm cung và hướng bắn hiện tại (nằm ngang)
func _place() -> void:
	if player == null:
		return
	var grip := player.get_bow_grip_transform().origin
	var forward := player.get_bow_aim_direction()
	if forward.is_zero_approx():
		forward = player.get_facing_direction()
	forward.y = 0.0
	forward = forward.normalized()
	var side := Vector3.UP.cross(forward).normalized()
	var length := lerpf(pointer_min_length, pointer_length, _draw) if _aiming else pointer_length
	var start := grip + forward * pointer_offset
	_pointer.global_transform = Transform3D(Basis(side * pointer_width, Vector3.UP, forward * length), start + forward * (length * 0.5))
	# Shader vẽ nét theo mét: báo cỡ thật để nét không bị kéo giãn khi mũi tên dài ra
	_pointer_mat.set_shader_parameter(&"pointer_size", Vector2(pointer_width, length))
	var line_start := start + forward * length
	_aim_line.global_transform = Transform3D(Basis(side * aim_line_width, Vector3.UP, forward * aim_line_length), line_start + forward * (aim_line_length * 0.5))
	if _ready_clock < 0.0:
		_arc.scale = Vector3.ONE * arc_size
	_arc.global_transform = Transform3D(Basis(side, Vector3.UP, forward).scaled(_arc.scale), grip)
	_light.global_position = grip + forward * 0.4
	_wind.global_position = line_start
	_sparks.global_position = line_start


func _hide_layers() -> void:
	_pointer.hide()
	_aim_line.hide()
	_arc.hide()
	_light.hide()


func _hide_all() -> void:
	_hide_layers()
	_puff.emitting = false
	_wind.emitting = false
	_sparks.emitting = false
	set_process(false)
