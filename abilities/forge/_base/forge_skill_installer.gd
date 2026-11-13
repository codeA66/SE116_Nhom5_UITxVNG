class_name ForgeSkillInstaller
extends Node
## Gắn state của các kỹ năng lò rèn vào StateMachine của player khi player xuất hiện trong khu (không sửa player.tscn).
## Đặt node này làm con trực tiếp của ZoneRoot. Gắn cho mọi kỹ năng trong danh sách, kể cả chưa học:
## player chỉ vào state khi đã học kỹ năng (Player.get_ready_skill), nên state thừa không ảnh hưởng gì.

@export var skills: Array[ForgeSkillData] = []


func _ready() -> void:
	var zone := get_parent() as ZoneRoot
	assert(zone != null, "ForgeSkillInstaller phải là con trực tiếp của ZoneRoot")
	zone.player_spawned.connect(install)


## Tạo state còn thiếu cho player (gọi lại nhiều lần không tạo trùng)
func install(player: Player) -> void:
	var machine := player.state_machine
	for skill: ForgeSkillData in skills:
		if skill == null or skill.state_script == null or machine.has_state(skill.state):
			continue
		var state := skill.state_script.new() as ForgePlayerState
		assert(state != null, "%s: state_script phải kế thừa ForgePlayerState" % skill.id)
		state.name = skill.state
		machine.add_state(state)
