extends DevCheat
## Một đòn chết: mọi hurtbox không phải của player nhận đòn là mất hết máu (quái, boss, vật phá được).
## Xét theo mục tiêu, không theo nguồn đòn: nguồn trong DamageInfo không đồng nhất (người bắn / viên đạn / null).
## Hurtbox đang invulnerable (boss bay, ngồi ngai) vẫn chặn trước khi tới đây nên giữ đúng luật miễn sát thương.

var _modifier: Callable


func _init() -> void:
	title = "Một đòn chết"
	group = "2. Combat"
	kind = Kind.TOGGLE
	order = 0
	_modifier = _kill_non_player


func apply(_console: DevConsole) -> void:
	if not HurtboxComponent.damage_modifiers.has(_modifier):
		HurtboxComponent.damage_modifiers.append(_modifier)


func remove(_console: DevConsole) -> void:
	HurtboxComponent.damage_modifiers.erase(_modifier)


func _kill_non_player(hurtbox: HurtboxComponent, _info: DamageInfo, damage: int) -> int:
	if hurtbox.owner is Player or hurtbox.health == null:
		return damage
	return maxi(damage, hurtbox.health.current_health)
