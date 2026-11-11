class_name StateMachine
extends Node

signal state_changed(from: StringName, to: StringName)

@export var initial_state: State

var current_state: State

var _states: Dictionary[StringName, State] = {}

func _ready() -> void:
	for child in get_children():
		if child is State:
			_states[child.name] = child
			child.state_machine = self
	# Chờ owner sẵn sàng để state đầu tiên dùng được các @onready của owner
	await owner.ready
	current_state = initial_state
	current_state.enter(&"")
	
func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

## Thêm state lúc chạy (kỹ năng gắn thêm vào entity mà không sửa scene gốc). Trùng tên thì bỏ qua, trả false
func add_state(state: State) -> bool:
	if _states.has(state.name):
		return false
	if state.get_parent() != self:
		add_child(state)
	_states[state.name] = state
	state.state_machine = self
	return true


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


func transition_to(state_name: StringName) -> void:
	var next: State = _states.get(state_name)
	if next == null:
		push_error("StateMachine: không có state '%s'" % state_name)
		return
	var previous := current_state.name
	current_state.exit()
	current_state = next
	current_state.enter(previous)
	state_changed.emit(previous, state_name)
