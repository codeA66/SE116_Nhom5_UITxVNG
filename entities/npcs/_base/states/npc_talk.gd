class_name NpcTalk
extends NpcState
## Nói một đoạn thoại theo context đang chờ (chào / tạm biệt / context riêng), quay mặt về cáo trong lúc nói.
## Nói xong: đoạn có opens_service và NPC có service mở được -> Serve, còn lại -> Idle.
## Bấm thoát giữa chừng -> Idle ngay (không bật cờ của đoạn).

@export var idle_state: StringName = &"Idle"
@export var serve_state: StringName = &"Serve"

## Tăng mỗi lần vào state: coroutine của lượt cũ (đang await) biết mình đã hết hiệu lực
var _run_id: int = 0


func enter(_previous: StringName) -> void:
	_run_id += 1
	npc.set_physics_process(true)
	npc.play_animation(npc.talk_animation)
	_run(_run_id, npc.pick_dialogue(npc.consume_context()))


func exit() -> void:
	_run_id += 1
	npc.set_physics_process(false)


func physics_update(delta: float) -> void:
	if is_instance_valid(npc.current_player):
		npc.turn_toward(npc.current_player.global_position, delta)


func _run(run_id: int, dialogue: Dialogue) -> void:
	if dialogue == null:
		# Không có lời nào hợp lệ: vẫn mở được service (NPC chỉ làm việc, không nói)
		_go_next(run_id, npc.get_service())
		return
	var result: int = await npc.say(dialogue.lines)
	if run_id != _run_id:
		return
	if result == DialogueBox.RESULT_CANCELLED:
		state_machine.transition_to(idle_state)
		return
	GameState.set_flag(dialogue.flag_on_finish)
	_go_next(run_id, npc.get_service() if dialogue.opens_service else null)


func _go_next(run_id: int, service: NpcService) -> void:
	if service == null:
		# Đợi một nhịp để không chuyển state ngay trong enter() của chính state này
		await get_tree().process_frame
		if run_id == _run_id:
			state_machine.transition_to(idle_state)
		return
	if not service.keep_dialogue_open:
		npc.close_dialogue()
	await get_tree().process_frame
	if run_id == _run_id:
		state_machine.transition_to(serve_state)
