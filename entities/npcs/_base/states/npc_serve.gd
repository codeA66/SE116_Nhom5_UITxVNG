class_name NpcServe
extends NpcState
## Mở service của NPC (nâng cấp, cửa hàng, thu tiền...) và chờ nó đóng.
## Đóng xong: có lời tạm biệt hợp lệ thì quay lại Talk với context tạm biệt, không thì về Idle.

@export var idle_state: StringName = &"Idle"
@export var talk_state: StringName = &"Talk"

var _service: NpcService


func enter(_previous: StringName) -> void:
	_service = npc.get_service()
	if _service == null or not is_instance_valid(npc.current_player):
		_leave.call_deferred(false)
		return
	_service.closed.connect(_on_service_closed, CONNECT_ONE_SHOT)
	_service.open(npc, npc.current_player)


func exit() -> void:
	if _service == null:
		return
	if _service.closed.is_connected(_on_service_closed):
		_service.closed.disconnect(_on_service_closed)
	# Rời state vì lý do khác (NPC bị xóa...): đóng luôn màn của service
	_service.finish(true)
	_service = null


## Bấm thoát trong service -> về Idle luôn, không chào
func _on_service_closed(cancelled: bool) -> void:
	_leave(not cancelled and npc.pick_dialogue(Npc.CONTEXT_FAREWELL) != null)


func _leave(say_farewell: bool) -> void:
	if state_machine.current_state != self:
		return
	if say_farewell:
		npc.request_context(Npc.CONTEXT_FAREWELL)
		state_machine.transition_to(talk_state)
	else:
		state_machine.transition_to(idle_state)
