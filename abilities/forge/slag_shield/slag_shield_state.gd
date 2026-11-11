extends ForgePlayerState
## Khiên xỉ: giữ phím thì dựng khiên. Trong lúc giữ, hurtbox gốc của player tắt monitorable và hurtbox của khiên
## (cùng hình, cùng layer) bật lên thay: đòn trong cung trước mặt bị chặn, đòn khác chuyển cho hurtbox gốc.
## Đi chậm, mặt luôn hướng về phía nhắm; cứ drain_interval giây tốn 1 năng lượng, hết thì hạ khiên.

const PLAYER_HURTBOX := ^"HurtboxComponent"
const PLAYER_HURTBOX_SHAPE := ^"HurtboxComponent/CollisionShape3D"

var _data: SlagShieldData
var _shield: Node3D
var _hurtbox: SlagShieldHurtbox
var _guard: DirectionalHitGuard
var _visual: Node3D
var _player_hurtbox: HurtboxComponent
var _aim: Vector3 = Vector3.FORWARD
var _elapsed: float = 0.0
var _drain: float = 0.0


func enter(_previous: StringName) -> void:
	_data = player.start_skill(SlagShieldData.ID) as SlagShieldData
	_ensure_shield()
	_aim = get_cast_direction()
	_elapsed = 0.0
	_drain = 0.0
	player.face_instantly(_aim)
	player.play_anim(_data.animation)
	_raise()


func exit() -> void:
	_lower()


func physics_update(delta: float) -> void:
	_elapsed += delta
	_drain += delta
	if _drain >= _data.drain_interval:
		_drain -= _data.drain_interval
		if not player.energy.spend(1):
			finish()
			return
	var held := player.controls_enabled and Input.is_action_pressed(_data.input_action)
	if not held and _elapsed >= _data.min_hold:
		finish()
		return
	var mouse_aim := player.get_mouse_aim_direction()
	if not mouse_aim.is_zero_approx():
		_aim = mouse_aim.normalized()
	player.apply_gravity(delta)
	player.move_toward_direction(player.get_move_direction() * _data.move_scale, delta)
	# move_toward_direction xoay model theo hướng đi; khiên giữ mặt về hướng nhắm
	player.face_instantly(_aim)
	_visual.rotation.y = player.model.rotation.y


func is_raised() -> bool:
	return _hurtbox != null and _hurtbox.monitorable


## Tạo khiên một lần (con của player), lấy hình hurtbox gốc để vùng nhận đòn khớp người
func _ensure_shield() -> void:
	if is_instance_valid(_shield):
		return
	_player_hurtbox = player.get_node(PLAYER_HURTBOX) as HurtboxComponent
	_shield = _data.shield_scene.instantiate() as Node3D
	player.add_child(_shield)
	_hurtbox = _shield.get_node(^"Hurtbox") as SlagShieldHurtbox
	_guard = _shield.get_node(^"Hurtbox/Guard") as DirectionalHitGuard
	_visual = _shield.get_node(^"Visual") as Node3D
	var source_shape := player.get_node(PLAYER_HURTBOX_SHAPE) as CollisionShape3D
	var shape := _shield.get_node(^"Hurtbox/Shape") as CollisionShape3D
	shape.shape = source_shape.shape
	shape.transform = source_shape.transform
	_hurtbox.guards.assign([_guard])
	_hurtbox.forward_to = _player_hurtbox
	_hurtbox.reflect_source = player
	_guard.facing_node = player.model
	# HurtboxComponent tự bật monitorable trong _ready: khiên chưa giơ thì tắt
	_hurtbox.monitorable = false
	_visual.visible = false


func _raise() -> void:
	_guard.arc_degrees = _data.arc_degrees
	_hurtbox.reflects_projectiles = _data.reflects_projectiles
	_hurtbox.collision_layer = _player_hurtbox.collision_layer
	# Đổi ngay (không deferred) để không có frame nào cả hai cùng tắt / cùng bật
	_player_hurtbox.monitorable = false
	_hurtbox.monitorable = true
	_visual.rotation.y = player.model.rotation.y
	_visual.visible = true


func _lower() -> void:
	if _hurtbox == null:
		return
	# Hạ khiên có thể xảy ra giữa lúc engine phát signal va chạm (bị đánh sau lưng -> Hurt): đổi monitorable kiểu deferred
	_hurtbox.set_deferred(&"monitorable", false)
	_player_hurtbox.set_deferred(&"monitorable", true)
	_visual.visible = false
