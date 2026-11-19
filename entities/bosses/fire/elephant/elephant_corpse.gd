extends EnemyState

var _elephant: WarElephant
var _viewer: Node3D
var _settled: bool
var _body_transform: Transform3D
var _body_size: Vector3
var _hurtbox_layer: int


func enter(_previous: StringName) -> void:
	_elephant = enemy as WarElephant
	_settled = false
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


func exit() -> void:
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
	if _settled and not _elephant.keep_test_corpse and is_instance_valid(_viewer):
		if enemy.global_position.distance_squared_to(_viewer.global_position) >= _elephant.corpse_distance ** 2:
			enemy.queue_free()


func _land(_clip: StringName) -> void:
	var shape := _elephant.body_collision
	var yaw := _elephant.model.rotation.y
	(shape.shape as BoxShape3D).size = _elephant.corpse_size
	shape.rotation.y = yaw
	shape.position = _elephant.corpse_offset.rotated(Vector3.UP, yaw)
	_settled = true
	_elephant.corpse_settled.emit()
