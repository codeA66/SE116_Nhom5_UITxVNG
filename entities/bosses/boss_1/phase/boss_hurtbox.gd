class_name BossHurtbox
extends HurtboxComponent
## Khiên chặn đòn trước khi cấp i-frame và phát phản hồi trúng đòn.

func receive_hit(info: DamageInfo) -> bool:
	var phases: BossPhaseController = health as BossPhaseController
	if phases != null and phases.is_shielded:
		return false
	return super.receive_hit(info)


func _apply_damage(amount: int) -> int:
	var phases: BossPhaseController = health as BossPhaseController
	phases.take_damage(amount)
	return phases.last_damage_taken
