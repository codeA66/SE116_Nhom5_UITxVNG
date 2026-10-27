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
