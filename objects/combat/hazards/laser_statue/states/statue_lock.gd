extends StatueState
## Khóa: đường tia đứng yên, đường cảnh báo và tia nháy trắng lock_flashes lần.
## Player tiến / lùi ra khỏi đường lúc này là né được.

@export var fire_state: StringName = &"StatueFire"

var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	statue.set_beam(LaserStatue.BeamMode.LOCK)
	statue.aim_beam_at(statue.line_start())
	statue.locked.emit(statue.aim_point)


func physics_update(delta: float) -> void:
	_elapsed += delta
	var data := statue.data
	# Nháy: đổi màu theo nhịp, không tạo vật liệu mới; tia chỉ sẵn vào đầu đường nơi sẽ bắt đầu quét
	var on := int(_elapsed / data.lock_time * data.lock_flashes * 2.0) % 2 == 0
	statue.set_beam_color(data.lock_color if on else data.aim_color)
	var warn := data.lock_color if on else data.warn_color
	warn.a = data.warn_color.a * (2.0 if on else 1.0)
	statue.show_warning(warn)
	if _elapsed >= data.lock_time:
		state_machine.transition_to(fire_state)
