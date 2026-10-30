@tool
class_name AbilitySkillSlot
extends SkillSlot
## Ô kỹ năng mở khóa (wind blast, ...): rỗng khi chưa có kỹ năng trong tiến trình.

## Trùng AbilityData.id của kỹ năng (vd. WindBlastData.ID = &"wind_blast")
@export var ability_id: StringName = &""


func is_available() -> bool:
	return GameState.has_ability(ability_id)


func is_ready() -> bool:
	return true


## Player phát skill_cooldown_started cho mọi kỹ năng: chỉ nhận của kỹ năng ô này
func on_skill_cooldown(skill_id: StringName, duration: float) -> void:
	if skill_id == ability_id:
		start_cooldown(duration)
