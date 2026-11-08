class_name HostageRescue
extends Node3D
## Thử thách cứu con tin bằng ròng rọc: con tin bị nhốt trong lồng (Cage) treo qua ròng rọc trên giàn (Gantry)
## bắc ngang hố dung nham, dây quấn về tời quay tay (Winch) trên bờ.
## - Player bước vào vùng: bọn quái canh (Encounter gán ở guards) đang hạ lồng dần xuống hố (lower_time giây
##   từ start_height tới fail_height); đồng hồ trên lồng báo còn bao lâu.
## - Hạ hết quái: lồng ngừng bị hạ, tời mở. Đứng ở tời giữ phím interact thì quay tời kéo lồng lên (crank_speed);
##   thả tay thì lồng tuột xuống chậm (slip_speed).
## - Lồng lên tới rescue_height: lồng khoá lại ngang sàn gỗ (Scaffold: bậc thang + cầu gỗ ra sát lồng).
##   Player leo lên, bấm interact ở lồng (MỞ LỒNG): con tin bước ra sàn (Shore), lưu cờ persistent_id,
##   phát rescued / activated.
## - Lồng xuống tới fail_height: dây đứt, lồng rơi vào dung nham (failed); ra khỏi vùng rồi vào lại thì làm lại.
## Dùng làm nguồn cho StoneGate qua is_active(). Thêm loại quái canh khác chỉ cần đổi quái trong Encounter.
## Hiệu năng: _physics_process chỉ bật khi lồng đang chuyển động (đang chạy thử thách); còn lại chỉ nghe signal.

signal started
signal rescued
signal failed
signal activated

enum Phase { WAITING, RUNNING, LIFTED, RESCUED, FAILED }

## Cờ lưu đã cứu. Trống = mỗi lần vào khu lại có con tin
@export var persistent_id: StringName
## Trận quái canh tời. Trống = không có quái, tời mở ngay
@export var guards: Encounter
## Vùng player bước vào thì bắt đầu (hộp, tâm đáy tại active_area_offset)
@export var active_area_size: Vector3 = Vector3(14.0, 4.0, 18.0)
@export var active_area_offset: Vector3 = Vector3.ZERO
@export_group("Heights")
## Độ cao móc lồng (so với gốc node, gốc ở mặt sàn giữa hố) lúc bắt đầu / khi cứu xong / khi dây đứt
@export var start_height: float = 3.2
## Lồng khoá ở độ cao này: sàn lồng ngang mặt cầu gỗ (móc - 2,23 m)
@export var rescue_height: float = 4.25
@export var fail_height: float = -2.0
@export_group("Speeds")
## Quái hạ lồng từ start_height tới fail_height trong bao lâu (s)
@export_range(1.0, 600.0, 0.5) var lower_time: float = 45.0
## Tốc độ kéo lên khi giữ tời (m/s)
@export_range(0.05, 20.0, 0.05) var crank_speed: float = 1.2
## Tốc độ tuột xuống khi thả tay (m/s, sau khi đã hạ hết quái)
@export_range(0.0, 20.0, 0.05) var slip_speed: float = 0.25
## Trống tời / bánh ròng rọc quay bao nhiêu radian mỗi mét dây
@export var spin_per_meter: float = 3.0
@export_group("Motion")
@export_range(0.1, 5.0, 0.05) var free_time: float = 0.8
@export var fall_depth: float = 9.0
@export_range(0.1, 5.0, 0.05) var fall_time: float = 0.9
@export_group("Label")
## Dưới mức này (s) nhãn đổi sang màu báo động
@export var warning_time: float = 10.0
@export var normal_color: Color = Color(1.0, 0.92, 0.7)
@export var warning_color: Color = Color(1.0, 0.25, 0.15)

var phase: Phase = Phase.WAITING
var guards_down: bool = false
var is_cranking: bool = false

var _at_winch: Node3D
var _motion: Tween
var _last_label: String = ""

@onready var _area: Area3D = $ActiveArea
@onready var _area_shape: CollisionShape3D = $ActiveArea/CollisionShape3D
@onready var _cage: Node3D = $Cage
@onready var _hostage: Node3D = $Cage/Hostage
@onready var _label: Label3D = $Cage/TimeLabel
@onready var _wheel: Node3D = $Gantry.find_child("Wheel", true, false) as Node3D
@onready var _drum: Node3D = $Winch.find_child("Drum", true, false) as Node3D
@onready var _rope_down: Node3D = $RopeDown
@onready var _rope_winch: Node3D = $RopeWinch
@onready var _shore: Marker3D = $Shore
@onready var _winch_area: Area3D = $Winch/CrankArea
@onready var _winch_prompt: InteractableComponent = $Winch/InteractableComponent
@onready var _cage_prompt: InteractableComponent = $Cage/InteractableComponent


func _ready() -> void:
	var box: BoxShape3D = _area_shape.shape as BoxShape3D
	box.size = active_area_size
	_area_shape.position = active_area_offset + Vector3(0.0, active_area_size.y * 0.5, 0.0)
	set_physics_process(false)
	_winch_prompt.availability_check = func(_actor: Node3D) -> bool: return phase == Phase.RUNNING and guards_down
	_cage_prompt.availability_check = func(_actor: Node3D) -> bool: return phase == Phase.LIFTED
	_cage_prompt.interacted.connect(_on_cage_opened)
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_finish_rescued(true)
		return
	_set_cage_height(start_height)
	_label.hide()
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_winch_area.body_entered.connect(func(body: Node3D) -> void: _at_winch = body)
	_winch_area.body_exited.connect(func(body: Node3D) -> void: if body == _at_winch: _at_winch = null)
	if guards == null:
		guards_down = true
	else:
		guards.cleared.connect(_on_guards_cleared)
		# Trận đã thắng từ lần trước (Encounter tự bỏ quái): coi như đã hạ quái
		if not guards.persistent_id.is_empty() and GameState.has_flag(guards.persistent_id):
			guards_down = true


func is_active() -> bool:
	return phase == Phase.RESCUED


func cage_height() -> float:
	return _cage.position.y


## Còn bao lâu nữa lồng chạm mức đứt dây với tốc độ đang hạ hiện tại (s); không hạ thì INF
func time_to_fall() -> float:
	var speed: float = _down_speed()
	if speed <= 0.0:
		return INF
	return maxf(_cage.position.y - fail_height, 0.0) / speed


func _physics_process(delta: float) -> void:
	is_cranking = guards_down and _at_winch != null and Input.is_action_pressed(&"interact")
	var velocity: float = crank_speed if is_cranking else -_down_speed()
	var y: float = clampf(_cage.position.y + velocity * delta, fail_height, rescue_height)
	var moved: float = y - _cage.position.y
	_set_cage_height(y)
	if _wheel:
		_wheel.rotate_x(moved * spin_per_meter)
	if _drum:
		_drum.rotate_x(-moved * spin_per_meter)
	_update_label()
	if y >= rescue_height:
		_lock_at_top()
	elif y <= fail_height:
		_snap()


func _down_speed() -> float:
	if not guards_down:
		return (start_height - fail_height) / lower_time
	return slip_speed


func _on_body_entered(_body: Node3D) -> void:
	if phase != Phase.WAITING:
		return
	phase = Phase.RUNNING
	_update_label()
	set_physics_process(true)
	started.emit()


## Thất bại rồi: ra khỏi vùng thì treo lại lồng, lần vào sau bắt đầu lại
func _on_body_exited(_body: Node3D) -> void:
	if phase != Phase.FAILED:
		return
	if _motion:
		_motion.kill()
	_cage.show()
	_rope_down.show()
	_set_cage_height(start_height)
	phase = Phase.WAITING


func _on_guards_cleared() -> void:
	guards_down = true
	_update_label()


## Lồng lên tới đỉnh: khoá ngang cầu gỗ, chờ player leo lên mở
func _lock_at_top() -> void:
	phase = Phase.LIFTED
	is_cranking = false
	set_physics_process(false)
	_label.hide()
	_winch_prompt.enabled = false


func _on_cage_opened(_actor: Node3D) -> void:
	if phase != Phase.LIFTED:
		return
	phase = Phase.RESCUED
	_cage_prompt.enabled = false
	# Con tin bước ra cầu gỗ rồi về sàn (Shore)
	var target: Vector3 = _cage.to_local(_shore.global_position)
	_motion = create_tween()
	_motion.tween_property(_hostage, ^"position", target, free_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_motion.tween_callback(_finish_rescued.bind(false))


func _finish_rescued(instant: bool) -> void:
	phase = Phase.RESCUED
	set_physics_process(false)
	_label.hide()
	_winch_prompt.enabled = false
	_cage_prompt.enabled = false
	if instant:
		_set_cage_height(rescue_height)
		_hostage.global_position = _shore.global_position
		return
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	rescued.emit()
	activated.emit()


func _snap() -> void:
	phase = Phase.FAILED
	is_cranking = false
	set_physics_process(false)
	_label.hide()
	_rope_down.hide()
	_motion = create_tween()
	_motion.tween_property(_cage, ^"position:y", _cage.position.y - fall_depth, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion.tween_callback(_cage.hide)
	failed.emit()


func _set_cage_height(y: float) -> void:
	_cage.position.y = y
	var wheel_bottom: Vector3 = _wheel.global_position - global_basis.y * 0.28 if _wheel else global_position + Vector3.UP * 5.3
	_stretch(_rope_down, _cage.global_position, wheel_bottom)
	if _drum and _wheel:
		_stretch(_rope_winch, _drum.global_position + global_basis.y * 0.29, _wheel.global_position + global_basis.z * 0.28)


## Dây là trụ cao 1 m đặt giữa hai đầu: xoay trục Y theo hướng dây, kéo dài theo chiều dài
func _stretch(rope: Node3D, from: Vector3, to: Vector3) -> void:
	var dir: Vector3 = to - from
	var length: float = dir.length()
	if length < 0.01:
		rope.hide()
		return
	var y_axis: Vector3 = dir / length
	var x_axis: Vector3 = y_axis.cross(Vector3.FORWARD if absf(y_axis.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis)
	rope.global_transform = Transform3D(Basis(x_axis, y_axis * length, z_axis), (from + to) * 0.5)


## Đồng hồ chỉ hiện khi quái còn hạ lồng; hạ hết quái thì ẩn
func _update_label() -> void:
	_label.visible = not guards_down and phase == Phase.RUNNING
	if not _label.visible:
		return
	var left: float = time_to_fall()
	var text: String = "%d" % ceili(left)
	var color: Color = warning_color if left <= warning_time else normal_color
	if text != _last_label:
		_last_label = text
		_label.text = text
	_label.modulate = color
