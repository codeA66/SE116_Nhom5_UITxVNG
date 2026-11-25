class_name BowDrawFeedback
extends Node3D
## Báo độ kéo cung cho người chơi, tách 4 lớp dễ nhận:
## 1. Vòng tiến độ dưới chân: chạy 0 -> 100% theo độ kéo; đầy thì đổi màu vàng và thở nhẹ (đang giữ được bắn).
## 2. Vòng bung trên sàn: một nhịp đúng lúc vừa đầy.
## 3. Tia lóe 4 cánh ở đầu mũi tên: cùng lúc vừa đầy.
## 4. Khói xám ở đầu mũi tên + vòng xám co lại: thả sớm, phát này bị hủy (không bắn).
## Cỡ tính theo mét trong thế giới (đọc được ở camera 38 m), không phụ thuộc model cung, nên cung ghép nguyên tố
## cũng có. Nghe signal của Player, chỉ chạy _process khi có lớp đang hiện.

@export var player: Player

@export_group("Vòng tiến độ")
## Bán kính vòng dưới chân (m) và độ cao nhấc khỏi sàn (tránh chồng z)
@export_range(0.2, 5.0, 0.05) var ring_radius: float = 1.15
@export_range(0.0, 0.3, 0.005) var ring_lift: float = 0.04
## Vòng mờ dần khi bắn xong / thôi nhắm (s)
@export_range(0.01, 1.0, 0.01) var ring_fade_time: float = 0.15

@export_group("Kéo đầy")
@export_range(0.05, 1.0, 0.01) var burst_time: float = 0.3
## Vòng bung to tới bấy nhiêu lần bán kính vòng tiến độ
@export_range(1.0, 4.0, 0.05) var burst_scale: float = 2.0
@export_range(0.05, 1.0, 0.01) var glint_time: float = 0.2
## Cỡ tia lóe (m) và khoảng cách từ tay cầm cung tới đầu mũi tên (m)
@export_range(0.1, 4.0, 0.05) var glint_size: float = 1.3
@export_range(0.0, 2.0, 0.05) var tip_offset: float = 0.55

@export_group("Hủy")
@export_range(0.05, 1.0, 0.01) var cancel_time: float = 0.3

var _draw: float = 0.0
var _aiming: bool = false
var _ready_fired: bool = false
var _ring_fade: float = -1.0
var _burst_clock: float = -1.0
var _glint_clock: float = -1.0
var _cancel_clock: float = -1.0

@onready var _ring: MeshInstance3D = $Ring
@onready var _burst: MeshInstance3D = $ReadyBurst
@onready var _glint: MeshInstance3D = $Glint
@onready var _puff: CPUParticles3D = $CancelPuff
@onready var _ring_mat: ShaderMaterial = _ring.material_override as ShaderMaterial
@onready var _burst_mat: ShaderMaterial = _burst.material_override as ShaderMaterial
@onready var _glint_mat: ShaderMaterial = _glint.material_override as ShaderMaterial


func _ready() -> void:
	top_level = true
	_hide_all()
	if player == null:
		push_warning("%s: chưa gán player" % get_path())
		return
	player.bow_draw_progress.connect(_on_progress)
	player.bow_draw_cancelled.connect(_on_cancelled)


func _process(delta: float) -> void:
	_follow_player()
	var busy := false
	if _ring_fade >= 0.0:
		_ring_fade += delta
		var t := _ring_fade / ring_fade_time
		_ring_mat.set_shader_parameter(&"opacity", 1.0 - clampf(t, 0.0, 1.0))
		if t >= 1.0:
			_ring_fade = -1.0
			_ring.hide()
		else:
			busy = true
	if _cancel_clock >= 0.0:
		_cancel_clock += delta
		var t := _cancel_clock / cancel_time
		_ring.visible = t < 1.0
		_ring.scale = Vector3.ONE * ring_radius * lerpf(1.0, 0.55, clampf(t, 0.0, 1.0))
		_ring_mat.set_shader_parameter(&"opacity", 1.0 - clampf(t, 0.0, 1.0))
		if t >= 1.0:
			_cancel_clock = -1.0
		else:
			busy = true
	if _burst_clock >= 0.0:
		_burst_clock += delta
		var t := _burst_clock / burst_time
		_burst.visible = t < 1.0
		_burst_mat.set_shader_parameter(&"front", lerpf(0.35, 0.95, 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 2.0)))
		_burst_mat.set_shader_parameter(&"opacity", (1.0 - clampf(t, 0.0, 1.0)) * 1.6)
		if t >= 1.0:
			_burst_clock = -1.0
		else:
			busy = true
	if _glint_clock >= 0.0:
		_glint_clock += delta
		var t := _glint_clock / glint_time
		_glint.visible = t < 1.0
		var swell := sin(PI * clampf(t, 0.0, 1.0))
		_glint.scale = Vector3.ONE * maxf(glint_size * lerpf(0.4, 1.0, swell), 0.001)
		_glint_mat.set_shader_parameter(&"opacity", swell * 1.5)
		if t >= 1.0:
			_glint_clock = -1.0
		else:
			busy = true
	if _aiming or _puff.emitting:
		busy = true
	set_process(busy)


func _on_progress(amount: float) -> void:
	_draw = amount
	if amount > 0.0:
		if not _aiming:
			_start_aim()
		_ring_mat.set_shader_parameter(&"progress", amount)
		if amount >= 0.999 and not _ready_fired:
			_ready_fired = true
			_play_ready()
		return
	# Về 0: đã bắn hoặc thôi nhắm (hủy được báo riêng qua _on_cancelled trước đó)
	if _aiming:
		_aiming = false
		if _cancel_clock < 0.0:
			_ring_fade = 0.0
		set_process(true)


func _on_cancelled() -> void:
	_aiming = false
	_ready_fired = false
	_ring_fade = -1.0
	_ring_mat.set_shader_parameter(&"cancel", 1.0)
	_cancel_clock = 0.0
	_follow_player()
	_puff.global_position = _tip_position()
	_puff.restart()
	_puff.emitting = true
	set_process(true)


func _start_aim() -> void:
	_aiming = true
	_ready_fired = false
	_ring_fade = -1.0
	_cancel_clock = -1.0
	_ring.scale = Vector3.ONE * ring_radius
	_ring_mat.set_shader_parameter(&"ready", 0.0)
	_ring_mat.set_shader_parameter(&"cancel", 0.0)
	_ring_mat.set_shader_parameter(&"opacity", 1.0)
	_ring.show()
	_follow_player()
	set_process(true)


func _play_ready() -> void:
	_ring_mat.set_shader_parameter(&"ready", 1.0)
	_burst_clock = 0.0
	_burst.scale = Vector3.ONE * ring_radius * burst_scale
	_burst.show()
	_glint_clock = 0.0
	_glint.show()
	_follow_player()
	set_process(true)


func _follow_player() -> void:
	if player == null:
		return
	var feet := player.global_position + Vector3.UP * ring_lift
	_ring.global_position = feet
	_burst.global_position = feet
	_glint.global_position = _tip_position()


## Đầu mũi tên: từ tay cầm cung đi tới theo hướng bắn
func _tip_position() -> Vector3:
	var grip := player.get_bow_grip_transform()
	return grip.origin + grip.basis.z.normalized() * tip_offset


func _hide_all() -> void:
	_ring.hide()
	_burst.hide()
	_glint.hide()
	_puff.emitting = false
	set_process(false)
