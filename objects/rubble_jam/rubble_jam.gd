@tool
class_name RubbleJam
extends Node3D
## Đống đá vụn chèn cứng một thứ (cánh quạt...). Khi TẤT CẢ nguồn ở ô Sources đã bật (ví dụ ổ đá),
## gió gom xoáy rồi bung, đá văng tung, bụi phụt ra. Xong thì is_active() = true và phát activated:
## dùng làm nguồn mở khoá cho vật khác (trụ quạt locked_by...). Chỉ nghe đúng các nguồn được gán.
## Hướng văng chính là +Z cục bộ. Hành vi theo FSM dạng node (objects/rubble_jam/states/).

signal activated

@export var data: RubbleJamData
@export var sources: Array[Node] = []:
	set(value):
		sources = value
		update_configuration_warnings()
## Cờ lưu đã phá. Để trống = mỗi lần vào khu đá lại chèn
@export var persistent_id: StringName

var _cleared: bool = false

@onready var state_machine: StateMachine = $StateMachine
@onready var pieces: Node3D = $Pieces
@onready var dust: GPUParticles3D = $Dust
@onready var wind_burst: Node3D = $WindBurst


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	set_process(false)
	if data == null:
		push_error("%s thiếu RubbleJamData, đá không bao giờ vỡ" % get_path())
		return
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_cleared = true
		state_machine.initial_state = state_machine.get_node(NodePath(RubbleJamState.CLEARED)) as State
		return
	for source in sources:
		if source == null or not source.has_signal(&"activated") or not source.has_method(&"is_active"):
			push_error("%s: nguồn %s không có signal activated / hàm is_active()" % [get_path(), source])
			continue
		source.connect(&"activated", _refresh)
	_refresh.call_deferred()


func _get_configuration_warnings() -> PackedStringArray:
	if sources.is_empty():
		return ["Chưa gán nguồn ở ô Sources: đống đá sẽ không bao giờ vỡ."]
	return []


## Chỉ chạy trong lúc đang vỡ (state bật/tắt)
func _process(delta: float) -> void:
	state_machine.physics_update(delta)


func is_active() -> bool:
	return _cleared


## State gọi đúng lúc đá văng ra: mở khoá ngay, không bắt người chơi chờ mảnh rơi xong
func mark_cleared() -> void:
	if _cleared:
		return
	_cleared = true
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	activated.emit()


func _refresh() -> void:
	if _cleared or sources.is_empty():
		return
	for source in sources:
		if source == null or not source.call(&"is_active"):
			return
	(state_machine.current_state as RubbleJamState).on_unlocked()
