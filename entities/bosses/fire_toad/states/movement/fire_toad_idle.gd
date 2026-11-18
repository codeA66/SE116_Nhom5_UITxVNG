extends FireToadState
## Đứng nhìn player một lúc rồi chọn skill kế. Tới mốc máu thì bay lên (phase 2) trước, không cắt ngang skill.
## Skill chọn ngẫu nhiên trong danh sách, không lặp lại skill vừa dùng, bỏ skill court đang cấm (đồng đội đang dùng). Thêm skill = thêm state + tên vào skill_states.

## Tên các state skill được chọn
@export var skill_states: Array[StringName] = [&"FireRain", &"WebRetreat", &"LavaSlam"]
## Trạng thái bay lên khi tới mốc máu
@export var hover_state: StringName = &"Hover"

var _last_skill: StringName = &""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super()
	_rng.randomize()


func _run(id: int) -> void:
	toad.play_clip(&"Idle_Enraged" if toad.enraged else &"Idle", true)
	await ZoneRoot.wait_combat_ready(toad)
	var elapsed := 0.0
	var idle_time := toad.skills().idle_time
	while elapsed < idle_time:
		if not still_running(id):
			return
		if toad.consume_hover_request(hover_state):
			state_machine.transition_to(hover_state)
			return
		toad.face_player()
		await toad.get_tree().physics_frame
		elapsed += toad.get_physics_process_delta_time()
	if not still_running(id):
		return
	if toad.consume_hover_request(hover_state):
		state_machine.transition_to(hover_state)
		return
	state_machine.transition_to(_pick_skill())


func _pick_skill() -> StringName:
	var options: Array[StringName] = []
	for skill in skill_states:
		if skill != _last_skill and state_machine.has_state(skill) and toad.can_use_skill(skill):
			options.append(skill)
	if options.is_empty():
		for skill in skill_states:
			if state_machine.has_state(skill) and toad.can_use_skill(skill):
				options.append(skill)
	if options.is_empty():
		options = skill_states.duplicate()
	_last_skill = options[_rng.randi_range(0, options.size() - 1)]
	return _last_skill
