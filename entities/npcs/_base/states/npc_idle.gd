class_name NpcIdle
extends NpcState
## Đứng chờ. Cáo trong vùng nhìn thì quay dần theo cáo (cáo đi vòng quanh vẫn nhìn theo);
## cáo ra khỏi vùng thì tắt _physics_process. Vào state này = buổi nói chuyện (nếu có) kết thúc.

@export var talk_state: StringName = &"Talk"


func _ready() -> void:
	super()
	if npc == null:
		return
	npc.talk_requested.connect(_on_talk_requested)
	npc.look_target_changed.connect(_on_look_target_changed.unbind(1))


func enter(_previous: StringName) -> void:
	npc.end_session()
	npc.play_animation(npc.idle_animation)
	_update_processing()


func exit() -> void:
	npc.set_physics_process(false)


func physics_update(delta: float) -> void:
	if npc.look_target == null or not is_instance_valid(npc.look_target):
		npc.set_physics_process(false)
		return
	npc.turn_toward(npc.look_target.global_position, delta)


func _is_current() -> bool:
	return state_machine != null and state_machine.current_state == self


func _update_processing() -> void:
	npc.set_physics_process(npc.look_at_player and npc.look_target != null)


func _on_look_target_changed() -> void:
	if _is_current():
		_update_processing()


func _on_talk_requested(player: Player) -> void:
	if not _is_current():
		return
	npc.begin_session(player)
	state_machine.transition_to(talk_state)
