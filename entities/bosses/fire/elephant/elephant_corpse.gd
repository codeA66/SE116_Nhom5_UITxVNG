extends EnemyState

const SETTLE_PAUSE := 0.28

var _elephant: WarElephant
var _viewer: Node3D
var _death_framing: CameraCutscene
var _death_shot_offset: Vector3 = Vector3(5.2, 3.6, 6.2)
var _settled: bool
var _waiting_settle: bool = false
var _settle_timer: float = 0.0
var _body_transform: Transform3D
var _body_size: Vector3
var _hurtbox_layer: int


func _ready() -> void:
	super()
	_elephant = enemy as WarElephant
	_death_framing = _elephant.get_node_or_null("DeathFraming") as CameraCutscene
	if _death_framing and _death_framing.data:
		_death_shot_offset = _death_framing.data.shot_offset


func enter(_previous: StringName) -> void:
	_elephant = enemy as WarElephant
	_settled = false
	_waiting_settle = false
	_settle_timer = 0.0
	_body_transform = _elephant.body_collision.transform
	_body_size = (_elephant.body_collision.shape as BoxShape3D).size
	_hurtbox_layer = enemy.hurtbox.collision_layer
	_viewer = enemy.target
	if not is_instance_valid(_viewer):
		_viewer = get_tree().get_first_node_in_group(&"player") as Node3D
	_elephant.cancel_introduction()
	_elephant.lava.clear()
	enemy.forget_target()
	enemy.hitbox.cancel()
	enemy.hurtbox.set_deferred(&"monitorable", false)
	enemy.hurtbox.set_deferred(&"collision_layer", 0)
	enemy.set_dormant(true)
	enemy.wind_receiver.enabled = false
	enemy.external_forces_enabled = false
	enemy.velocity = Vector3.ZERO
	var animator := _elephant.animation_player()
	animator.animation_finished.connect(_land, CONNECT_ONE_SHOT)
	animator.play(_elephant.wildlife.death_animation, WarElephant.POSE_BLEND)
	HitStop.begin_cinematic(self, clampf(_elephant.true_death_time_scale, 0.15, 1.0))
	_start_death_zoom()


func exit() -> void:
	HitStop.end_cinematic(self)
	if _death_framing and _death_framing.is_processing():
		_death_framing.cancel_playback()
	var animator := _elephant.animation_player()
	if animator.animation_finished.is_connected(_land):
		animator.animation_finished.disconnect(_land)
	_elephant.body_collision.transform = _body_transform
	(_elephant.body_collision.shape as BoxShape3D).size = _body_size
	enemy.hurtbox.set_deferred(&"monitorable", true)
	enemy.hurtbox.set_deferred(&"collision_layer", _hurtbox_layer)
	enemy.external_forces_enabled = true


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	if _waiting_settle:
		_settle_timer += delta
		if _settle_timer >= SETTLE_PAUSE:
			_finish_death_cinematic()
	if _settled and not _elephant.keep_test_corpse and is_instance_valid(_viewer):
		if enemy.global_position.distance_squared_to(_viewer.global_position) >= _elephant.corpse_distance ** 2:
			enemy.queue_free()


func _start_death_zoom() -> void:
	if _death_framing == null or _death_framing.data == null or get_viewport().get_camera_3d() == null:
		return
	var viewer_player := _viewer as Player
	if viewer_player == null:
		return
	var forward := _elephant.model.global_basis.z.slide(Vector3.UP)
	if forward.length_squared() < 0.01:
		forward = Vector3.BACK
	else:
		forward = forward.normalized()
	var right := Vector3.UP.cross(forward).normalized()
	_death_framing.data.shot_offset = right * _death_shot_offset.x + Vector3.UP * _death_shot_offset.y + forward * _death_shot_offset.z
	_death_framing.unscaled_time = true
	_death_framing.hold_indefinitely = true
	_death_framing.play_for(viewer_player)


func _land(_clip: StringName) -> void:
	var shape := _elephant.body_collision
	var yaw := _elephant.model.rotation.y
	(shape.shape as BoxShape3D).size = _elephant.corpse_size
	shape.rotation.y = yaw
	shape.position = _elephant.corpse_offset.rotated(Vector3.UP, yaw)
	_waiting_settle = true
	_settle_timer = 0.0


func _finish_death_cinematic() -> void:
	_waiting_settle = false
	HitStop.end_cinematic(self)
	if _death_framing and _death_framing.is_processing():
		_death_framing.release_hold()
	_settled = true
	_elephant.corpse_settled.emit()
