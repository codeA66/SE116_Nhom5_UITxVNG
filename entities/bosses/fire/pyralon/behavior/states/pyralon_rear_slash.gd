extends PyralonAttackState

var _heading: Vector3
var _slashed: bool


func enter(previous: StringName) -> void:
	super(previous)
	_heading = -bird.get_facing_direction()
	_slashed = false


func physics_update(delta: float) -> void:
	tick_pose(delta)
	stay_in_place(delta)
	bird.update_axe_hit(skill, elapsed)
	if not _slashed and elapsed >= skill.active_start:
		_slashed = true
		var speed := bird.player_speed() * bird.profile.radial_speed_ratio * bird.profile.arc_speed_ratio
		var origin := bird.pose.axe_edge().lerp(bird.global_position, 0.6)
		bird.field.effect(PyralonFireFx.Kind.SHOCK, bird.field.floor_at(origin), _heading, Vector2.ONE * 1.35, 0.24)
		bird.field.ground.slash(origin, _heading, speed)
	if elapsed >= skill.duration:
		bird.finish_move(skill)
