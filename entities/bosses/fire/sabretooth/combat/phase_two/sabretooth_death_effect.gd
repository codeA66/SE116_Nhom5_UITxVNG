extends DeathEffectComponent
## Boss Hổ có animation ngã gục riêng cho cả chuyển pha Phase 1 -> 2 lẫn chết thật ở Phase 2,
## nên không chạy hiệu ứng co model biến mất của quái thường.


func _on_died() -> void:
	return
