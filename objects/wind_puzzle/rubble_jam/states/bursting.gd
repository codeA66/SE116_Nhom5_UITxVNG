extends RubbleJamState
## Pha 1 (charge_time): gió gom xoáy quanh đống đá, đá rung mạnh dần.
## Pha 2: gió bung, bụi phụt, rung màn hình; mỗi mảnh văng theo hướng riêng (tỏa ra + chếch lên + về +Z),
## xoay, rơi theo trọng lực, quãng cuối thu nhỏ rồi ẩn. Hết lifetime thì sang Cleared.

var _elapsed: float = 0.0
var _launched: bool = false
## Dữ liệu từng mảnh, cấp phát một lần khi bắt đầu vỡ (không cấp phát mỗi frame)
var _velocities: Array[Vector3] = []
var _spins: Array[Vector3] = []
var _rest: Array[Vector3] = []
var _scales: Array[Vector3] = []


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_launched = false
	var pieces := jam.pieces.get_children()
	_rest.clear()
	_scales.clear()
	for p in pieces:
		_rest.append((p as Node3D).position)
		_scales.append((p as Node3D).scale)
	if jam.wind_burst.has_method(&"start_charge"):
		jam.wind_burst.call(&"start_charge", jam.data.charge_time)
	jam.set_process(true)


func physics_update(delta: float) -> void:
	var d := jam.data
	_elapsed += delta
	var pieces := jam.pieces.get_children()
	if not _launched:
		# Rung mạnh dần theo tiến độ gom gió
		var k := clampf(_elapsed / maxf(d.charge_time, 0.001), 0.0, 1.0)
		for i in pieces.size():
			var amp := d.charge_shake * k
			(pieces[i] as Node3D).position = _rest[i] + Vector3(randf_range(-amp, amp), randf_range(-amp, amp), randf_range(-amp, amp))
		if _elapsed >= d.charge_time:
			_launch(pieces)
		return
	var t := _elapsed - d.charge_time
	var gravity := jam.global_basis.inverse() * Vector3.DOWN * d.gravity
	var shrink_start := d.lifetime * (1.0 - d.shrink_fraction)
	for i in pieces.size():
		var p := pieces[i] as Node3D
		_velocities[i] += gravity * delta
		p.position += _velocities[i] * delta
		p.rotation += _spins[i] * delta
		if t > shrink_start:
			var s := 1.0 - clampf((t - shrink_start) / maxf(d.lifetime - shrink_start, 0.001), 0.0, 1.0)
			p.scale = _scales[i] * maxf(s, 0.001)
	if t >= d.lifetime:
		state_machine.transition_to(CLEARED)


func _launch(pieces: Array[Node]) -> void:
	var d := jam.data
	_launched = true
	_velocities.clear()
	_spins.clear()
	for i in pieces.size():
		var p := pieces[i] as Node3D
		p.position = _rest[i]
		# Toả ra từ tâm theo mặt XY cục bộ, cộng hướng trước (+Z) và chếch lên
		var radial := Vector3(p.position.x, p.position.y, 0.0)
		radial = radial.normalized() if radial.length() > 0.01 else Vector3(randf_range(-1, 1), randf_range(-1, 1), 0).normalized()
		var dir := (radial * 0.8 + Vector3.BACK * 0.9 + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))).normalized()
		var up_local := jam.global_basis.inverse() * Vector3.UP
		_velocities.append(dir * randf_range(d.speed_min, d.speed_max) + up_local * d.upward)
		var spin := deg_to_rad(d.spin_degrees)
		_spins.append(Vector3(randf_range(-spin, spin), randf_range(-spin, spin), randf_range(-spin, spin)))
	jam.dust.restart()
	jam.dust.emitting = true
	if jam.wind_burst.has_method(&"play"):
		jam.wind_burst.call(&"play", false)
	if d.trauma > 0.0:
		ScreenShake.add_trauma(d.trauma)
	jam.mark_cleared()
