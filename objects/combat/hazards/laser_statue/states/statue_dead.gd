extends StatueState
## Vỡ: tắt hết tia / vùng / phát hiện, model sụp xuống; không chuyển đi đâu nữa.
## Vào từ đầu (đã vỡ trong save) thì sụp ngay, không diễn lại.


func enter(previous: StringName) -> void:
	statue.crumble(previous == &"StatueIdle" and statue.health.current_health > 0)
	statue.set_physics_process(false)
