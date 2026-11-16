class_name BossPhaseController
extends HealthComponent
## Chặn sát thương vượt mốc trước khi HealthComponent có thể phát died.

signal phase_changed(phase: int)

var data: BossData
var current_phase: int = 1
var is_shielded: bool = false
var shield_stacks: int = 0
var last_damage_taken: int = 0


func configure(config: BossData) -> void:
	data = config
	max_health = maxi(data.max_health, 1)
	heal_full()


func take_damage(amount: int) -> void:
	last_damage_taken = 0
	if data == null or is_shielded or is_dead() or amount <= 0:
		return
	var threshold: int = 0
	if current_phase == 1:
		threshold = maxi(int(max_health * clampf(data.phase2_health_ratio, 0.0, 1.0)), 1)
	elif current_phase == 2:
		threshold = maxi(int(max_health * clampf(data.phase3_health_ratio, 0.0, clampf(data.phase2_health_ratio, 0.0, 1.0))), 1)
	if threshold > 0 and current_health - amount <= threshold:
		# Khóa khiên trước các signal để đòn lồng nhau không xuyên mốc phase.
		is_shielded = true
		var next_phase: int = current_phase + 1
		last_damage_taken = maxi(current_health - threshold, 0)
		super.take_damage(last_damage_taken)
		current_phase = next_phase
		if current_phase == 3:
			set_current_health(maxi(int(max_health * clampf(data.phase3_recovery_ratio, 0.0, 1.0)), 1))
		phase_changed.emit(current_phase)
		return
	last_damage_taken = mini(current_health, amount)
	super.take_damage(amount)
