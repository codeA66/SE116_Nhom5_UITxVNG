extends EnemyState
## WindReceiver điều khiển quãng hất; ngòi nổ chỉ chốt sau khi lực đẩy kết thúc/chạm vật cản.
var _bomber: BananaBomber
var _receiver: BomberWindReceiver
var _settled: float = 0.0
var _direction: Vector3

func enter(_previous: StringName) -> void:
	_bomber = enemy as BananaBomber
	_receiver = enemy.wind_receiver as BomberWindReceiver
	_settled = 0.0
	_bomber.begin_wind_launch(_receiver.launch_duration())
	_direction = _bomber.wind_launch_direction
	if enemy.banana_slip.active: enemy.banana_slip.stop()
	enemy.velocity.x = 0.0; enemy.velocity.z = 0.0
	enemy.hitbox.deactivate(); enemy.set_telegraph(false)
	enemy.play_action(ANIM_HURT)

func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.velocity.x = 0.0; enemy.velocity.z = 0.0
	for index: int in enemy.get_slide_collision_count():
		var normal: Vector3 = enemy.get_slide_collision(index).get_normal()
		if absf(normal.y) < WindReceiverComponent.WALL_NORMAL_MAX_Y and normal.dot(_direction) < -0.5:
			_receiver.stop_launch(); break
	if _receiver.is_being_pushed(): _settled = 0.0; return
	_settled += delta
	if _settled >= _bomber.wind_detonation_delay: _bomber.detonate_after_wind()

func exit() -> void:
	_bomber.end_wind_launch()
