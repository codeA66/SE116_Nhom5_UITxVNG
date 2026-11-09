extends SkillShrineState
## Đã học: bệ trống, không còn cột năng lượng hay hiệu ứng khi đến gần.


func enter(_previous: StringName) -> void:
	shrine.set_presence(0.0, 0.0, 0.0, false, 0.6)
	shrine.set_rune_visible(false)
	shrine.set_mood(0.0, 0.0, 0.0, 0.3)
