extends DeathEffectComponent
## Hết máu phase đầu là biến hình, không chạy hiệu ứng co model của quái thường.


func _on_died() -> void:
	if (owner as FireSabretooth).is_phase_one():
		return
	super()
