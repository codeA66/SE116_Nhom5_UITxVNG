extends FireToadState
## Skill 1, Mưa Hoả Cầu: phun cầu lửa lên trời, vòng báo hiện trên sàn rồi rơi xuống nổ.
## Quả đầu nhắm thẳng chỗ player đứng, các quả còn lại rải quanh player trong rain_spread (luôn nằm trong sàn).

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super()
	_rng.randomize()


func _run(id: int) -> void:
	var skills := toad.skills()
	toad.face_player()
	toad.play_clip(&"Spit_Up")
	toad.vfx.charge_rain(skills.rain_windup)
	await wait(skills.rain_windup)
	for wave in skills.rain_waves:
		if not still_running(id):
			return
		toad.vfx.spit_up(skills.rain_count)
		_drop_wave(skills)
		if wave < skills.rain_waves - 1:
			await wait(skills.rain_wave_gap)
	await wait(skills.rain_warn_time + skills.rain_recover)
	finish(id)


func _drop_wave(skills: FireToadSkills) -> void:
	var center := toad.player_position()
	for i in skills.rain_count:
		var target := center
		if i > 0:
			var angle := _rng.randf() * TAU
			var distance := sqrt(_rng.randf()) * skills.rain_spread
			target = center + Vector3(cos(angle), 0.0, sin(angle)) * distance
		toad.drop_fireball(toad.clamp_to_arena(target), skills.rain_warn_time, skills.rain_radius)
