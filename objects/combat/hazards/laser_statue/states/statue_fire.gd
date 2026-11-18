extends StatueState
## Quét: đầu tia chạy dọc đường từ line_start tới line_end trong sweep_time; tia lớn từ mắt bám theo đầu tia,
## vệt cháy kéo dài phía sau, vùng sát thương đi theo đầu tia (đoạn bị tường chặn thì không gây sát thương).

@export var cooldown_state: StringName = &"StatueCooldown"

var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	statue.hide_warning()
	statue.set_beam(LaserStatue.BeamMode.FIRE)
	statue.shake()
	statue.fired.emit(statue.line_start(), statue.line_end())
	_sweep(0.0)


func exit() -> void:
	statue.disable_damage()
	statue.fade_trail()


func physics_update(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / statue.data.sweep_time
	_sweep(t)
	if t >= 1.0:
		state_machine.transition_to(cooldown_state)


func _sweep(t: float) -> void:
	var head := statue.line_point(t)
	var beam := statue.aim_beam_at(head)
	statue.show_trail(head)
	statue.damage_at(head, not beam[&"blocked"])
