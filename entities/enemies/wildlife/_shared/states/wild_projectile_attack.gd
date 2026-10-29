extends WildSkillAttack
## Đòn ném không dịch chuyển chân/body; cooldown bắt đầu ngay lúc đạn rời tay.
var _projectile: ProjectileSkillData
var _launcher: EnemyProjectileEmitter

func enter(previous: StringName) -> void:
	super(previous)
	_projectile = _skill as ProjectileSkillData
	_launcher = _actor.get_node(^"ProjectileEmitter") as EnemyProjectileEmitter
	_launcher.prepare_cast(_projectile)

func physics_update(delta: float) -> void:
	# Tung đạn trước khi super kết thúc đòn và chuyển state ở frame cuối.
	if not _cooldown_started and _elapsed + delta * _speed_scale >= _projectile.release_time:
		_launcher.launch(_projectile, _facing)
		_actor.start_skill_cooldown(_skill)
		_cooldown_started = true
	super(delta)

func exit() -> void:
	_launcher.finish_cast()
	# Bị hủy trước khi ném: chưa có đạn nên không khởi động cooldown ở exit của lớp cơ sở.
	_cooldown_started = true
	super()

func _apply_motion(_previous: float, _delta: float) -> void:
	_actor.velocity.x = 0.0
	_actor.velocity.z = 0.0
