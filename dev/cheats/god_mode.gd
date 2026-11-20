extends DevCheat
## Bất tử: đòn trúng player còn 0 máu. Vẫn phát hurt nên player vẫn nháy sáng, vẫn bị đẩy lùi như thường.

var _modifier: Callable


func _init() -> void:
	title = "Bất tử"
	group = "1. Player"
	kind = Kind.TOGGLE
	order = 0
	_modifier = _zero_for_player


func apply(_console: DevConsole) -> void:
	if not HurtboxComponent.damage_modifiers.has(_modifier):
		HurtboxComponent.damage_modifiers.append(_modifier)


func remove(_console: DevConsole) -> void:
	HurtboxComponent.damage_modifiers.erase(_modifier)


func _zero_for_player(hurtbox: HurtboxComponent, _info: DamageInfo, damage: int) -> int:
	return 0 if hurtbox.owner is Player else damage
