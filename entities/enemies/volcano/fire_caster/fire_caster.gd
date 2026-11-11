class_name FireCaster
extends Enemy
## Quỷ Xương Lửa: pháp sư đi bộ của map lửa. Đuổi theo player, vào tầm thì đứng lại niệm rồi bắn cầu lửa sọ
## (trúng thì mất máu + bắt lửa). Kháng lửa, sợ gió (bị thổi thì ngắt niệm, bay xa hơn quái thường).
## Script này là API mỏng cho các state (FireChase, CastFireBolt): đường bắn, niệm, bắn cầu.
## Logic chọn hành vi nằm ở các state.

signal bolt_fired(bolt: FireBolt)
## Bắt đầu / huỷ niệm (test và hiệu ứng nối vào)
signal cast_started
signal cast_cancelled

var caster_data: FireCasterData

var _los: bool = false
var _los_timer: float = 0.0
var _los_query: PhysicsRayQueryParameters3D
var _charge_tween: Tween
var _charging: bool = false

@onready var pool: ObjectPool = $BoltPool
## Cầu lửa trên tay: mesh riêng gắn vào xương Orb (BoneAttachment3D), nên phình to được khi niệm
@onready var _hand_orb: Node3D = $Model/Visual/FireCasterModel/FireCasterModel/Rig/Skeleton3D/Orb/OrbMesh
@onready var _cast_light: OmniLight3D = $Model/Visual/FireCasterModel/FireCasterModel/Rig/Skeleton3D/Orb/CastLight
@onready var skeleton: Skeleton3D = $Model/Visual/FireCasterModel/FireCasterModel/Rig/Skeleton3D
@onready var _cast_sound: AudioStreamPlayer3D = $CastSound
@onready var _fire_sound: AudioStreamPlayer3D = $FireSound


func _ready() -> void:
	caster_data = data as FireCasterData
	assert(caster_data != null, "%s: EnemyData phải là FireCasterData" % name)
	assert(caster_data.bolt != null, "%s: FireCasterData thiếu bolt" % name)
	super()
	hurtbox.resistances[DamageInfo.Type.FIRE] = caster_data.fire_damage_multiplier
	var burnable := get_node_or_null(^"BurnableComponent") as BurnableComponent
	if burnable and caster_data.fire_immune:
		burnable.set_enabled(false)
	_los_query = PhysicsRayQueryParameters3D.new()
	_los_query.collision_mask = caster_data.los_mask
	_los_query.exclude = [get_rid()]
	_cast_light.visible = false
	died.connect(_on_caster_died)


func _pre_state_update(delta: float) -> void:
	super(delta)
	_los_timer = maxf(_los_timer - delta, 0.0)


# ---------- Đường bắn ----------

## Có đường bắn thẳng từ nòng tới ngực mục tiêu (không bị tường che). Chỉ bắn tia mỗi los_check_interval
func has_line_of_sight() -> bool:
	if _los_timer > 0.0:
		return _los
	_los_timer = caster_data.los_check_interval
	if not has_target():
		_los = false
		return false
	_los_query.from = global_position + Vector3.UP * caster_data.muzzle_height
	_los_query.to = target.global_position + Vector3.UP * caster_data.target_height
	_los = get_world_3d().direct_space_state.intersect_ray(_los_query).is_empty()
	return _los


func invalidate_line_of_sight() -> void:
	_los_timer = 0.0


## Hướng ngắm 3D từ cầu trên tay tới ngực mục tiêu
func aim_direction() -> Vector3:
	if not has_target():
		return get_facing_direction()
	var aim_point := target.global_position + Vector3.UP * caster_data.target_height
	return (aim_point - _hand_orb.global_position).normalized()


# ---------- Niệm và bắn ----------

## Cầu trên tay phình to dần, đèn cam sáng dần trong duration giây (báo trước cho player né)
func begin_charge(duration: float) -> void:
	_kill_charge_tween()
	_charging = true
	_hand_orb.scale = Vector3.ONE * 0.6
	_cast_light.visible = true
	_cast_light.light_energy = 0.0
	if duration > 0.0:
		_charge_tween = create_tween().set_parallel()
		_charge_tween.tween_property(_hand_orb, ^"scale", Vector3.ONE * 1.5, duration)
		_charge_tween.tween_property(_cast_light, ^"light_energy", 2.5, duration)
	_play(_cast_sound)
	cast_started.emit()


## Dừng niệm (bắn xong hoặc bị ngắt): cầu về cỡ thường, tắt đèn
func cancel_charge() -> void:
	var was_charging := _charging
	_charging = false
	_kill_charge_tween()
	_hand_orb.scale = Vector3.ONE
	_cast_light.visible = false
	if was_charging:
		cast_cancelled.emit()


func is_charging() -> bool:
	return _charging


func fire_bolt(direction: Vector3) -> FireBolt:
	# Bắn xong là hết niệm, không tính là bị ngắt
	_charging = false
	cancel_charge()
	var bolt := pool.acquire() as FireBolt
	# Mỗi quả chỉ nối một lần dù được dùng lại nhiều lần
	if not bolt.finished.is_connected(pool.release):
		bolt.finished.connect(pool.release)
	bolt.launch(data.attack, caster_data.bolt, _hand_orb.global_position, direction, self)
	_play(_fire_sound)
	bolt_fired.emit(bolt)
	return bolt


func get_hand_position() -> Vector3:
	return _hand_orb.global_position


# ---------- Nội bộ ----------

func _kill_charge_tween() -> void:
	if _charge_tween:
		_charge_tween.kill()
		_charge_tween = null


func _play(sound: AudioStreamPlayer3D) -> void:
	if sound.stream:
		sound.play()


## Quái chết: cầu đang bay tan hết, không gây sát thương
func _on_caster_died(_enemy: Enemy) -> void:
	cancel_charge()
	for node: Node in pool.get_active():
		(node as FireBolt).dissipate()
