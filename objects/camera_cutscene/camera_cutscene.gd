@tool
class_name CameraCutscene
extends Node3D
## Cắt cảnh camera: player đi vào vùng Trigger thì khoá điều khiển, hiện viền đen, camera rời player
## trượt tới khung hình nhìn Focus Target, dừng nhìn (đẩy FOV vào, trôi nhẹ), rồi trượt về camera của player.
## Vật lý của player vẫn chạy (đang đứng trên thuyền vẫn được chở đi). Không bỏ qua được.
## Mỗi cutscene tự chứa camera và vùng kích hoạt riêng: nhiều cutscene trong một map không lẫn nhau.
## Hành vi theo FSM dạng node (objects/camera_cutscene/states/).

signal started
signal finished

@export var data: CameraCutsceneData
## Thứ camera hướng vào (ví dụ điểm boss quỳ)
@export var focus_target: Node3D:
	set(value):
		focus_target = value
		update_configuration_warnings()
## Cờ lưu đã xem. Để trống = chiếu lại mỗi lần đi vào vùng
@export var persistent_id: StringName
## Kích thước vùng kích hoạt (m), hộp đặt giữa đáy tại gốc node
@export var trigger_size: Vector3 = Vector3(4.0, 4.0, 2.0)

var player: Player
## Camera của player lúc bắt đầu (để trả lại khi xong)
var player_camera: Camera3D

@onready var state_machine: StateMachine = $StateMachine
@onready var camera: Camera3D = $CutCamera
@onready var _trigger: Area3D = $Trigger
@onready var _bar_top: ColorRect = $Letterbox/Top
@onready var _bar_bottom: ColorRect = $Letterbox/Bottom


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	var box := BoxShape3D.new()
	box.size = trigger_size
	var shape := _trigger.get_node("CollisionShape3D") as CollisionShape3D
	shape.shape = box
	shape.position.y = trigger_size.y * 0.5
	set_letterbox(0.0)
	if data == null or focus_target == null:
		push_error("%s thiếu data hoặc Focus Target, cutscene bị tắt" % get_path())
		_trigger.monitoring = false
		set_process(false)
		return
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_trigger.monitoring = false
		set_process(false)
		return
	_trigger.body_entered.connect(_on_body_entered)
	set_process(false)


func _get_configuration_warnings() -> PackedStringArray:
	if focus_target == null:
		return ["Chưa gán Focus Target: camera không biết nhìn vào đâu."]
	return []


## Chạy theo frame hiển thị (không theo physics) cho camera mượt; chỉ bật trong lúc cutscene chạy
func _process(delta: float) -> void:
	state_machine.physics_update(delta)


## Điểm camera nhìn vào
func get_look_point() -> Vector3:
	return focus_target.global_position + Vector3.UP * data.look_height


## Transform camera tại khung hình, xoay quanh mục tiêu orbit_degrees theo trục đứng
func get_shot_transform(orbit_degrees: float) -> Transform3D:
	var offset := data.shot_offset.rotated(Vector3.UP, deg_to_rad(orbit_degrees))
	var eye := focus_target.global_position + offset
	return Transform3D(Basis.IDENTITY, eye).looking_at(get_look_point(), Vector3.UP)


## 0 = không có viền, 1 = viền đủ letterbox_ratio
func set_letterbox(amount: float) -> void:
	var ratio := (data.letterbox_ratio if data else 0.0) * clampf(amount, 0.0, 1.0)
	_bar_top.anchor_bottom = ratio
	_bar_bottom.anchor_top = 1.0 - ratio
	_bar_top.visible = ratio > 0.0
	_bar_bottom.visible = ratio > 0.0


func begin(body_player: Player) -> void:
	player = body_player
	player_camera = get_viewport().get_camera_3d()
	player.set_controls_enabled(false)
	_set_hud_visible(false)
	camera.global_transform = player_camera.global_transform
	camera.fov = player_camera.fov
	camera.make_current()
	set_process(true)
	started.emit()


func end() -> void:
	set_process(false)
	set_letterbox(0.0)
	if is_instance_valid(player_camera):
		player_camera.make_current()
	if is_instance_valid(player):
		player.set_controls_enabled(true)
		_set_hud_visible(true)
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	finished.emit()


func _set_hud_visible(shown: bool) -> void:
	var hud := player.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = shown


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		(state_machine.current_state as CameraCutsceneState).on_player_entered(body as Player)
