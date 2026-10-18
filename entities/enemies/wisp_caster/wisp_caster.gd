class_name WispCaster
extends FlyingEnemy
## Pháp sư Hồn Trôi: quái bay đánh xa duy nhất. Giữ khoảng cách, niệm và bắn quả cầu hồn (gió phản được),
## thỉnh thoảng dịch chuyển. Script này chỉ là API mỏng cho các state (KeepDistance, CastOrb, Teleport):
## giữ bộ đếm / hồi chiêu, bắn cầu, ẩn / hiện thân. Logic chọn hành vi nằm ở các state.

signal orb_fired(orb: SpiritOrb)
## Dịch chuyển xong (đã tới chỗ mới)
signal teleported(from: Vector3, to: Vector3)

@export_group("Behaviour States")
@export var teleport_state: StringName = &"Teleport"

var caster_data: CasterEnemyData
## Số quả đã bắn kể từ lần dịch chuyển trước
var casts_since_teleport: int = 0

var _teleport_cooldown_left: float = 0.0
var _post_appear_left: float = 0.0
var _hurt_pending: bool = false
var _los: bool = false
var _los_timer: float = 0.0
var _hidden: bool = false
var _body_layer: int = 0
var _hurtbox_layer: int = 0
var _los_query: PhysicsRayQueryParameters3D
var _charge_tween: Tween
var _model_tween: Tween
var _marker_tween: Tween

@onready var pool: ObjectPool = $OrbPool
@onready var finder: TeleportPointFinder = $TeleportPointFinder
@onready var orb_spawn: Marker3D = $Model/OrbSpawn
@onready var _charge_orb: Node3D = $Model/OrbSpawn/ChargeOrb
@onready var _hand_orb: Node3D = $Model/Visual/WispCasterModel/WispCasterModel/Arm_R/Orb
@onready var _appear_marker: Node3D = $AppearMarker
@onready var _blob_shadow: Node3D = get_node_or_null(^"BlobShadow") as Node3D
@onready var _cast_sound: AudioStreamPlayer3D = $CastSound
@onready var _fire_sound: AudioStreamPlayer3D = $FireSound
@onready var _vanish_sound: AudioStreamPlayer3D = $VanishSound
@onready var _appear_sound: AudioStreamPlayer3D = $AppearSound
@onready var _hover_loop: AudioStreamPlayer3D = $HoverLoop


func _ready() -> void:
	caster_data = data as CasterEnemyData
	assert(caster_data != null, "%s: EnemyData phải là CasterEnemyData" % name)
	assert(caster_data.orb != null and caster_data.teleport != null and caster_data.hover != null, "%s: CasterEnemyData thiếu orb / teleport / hover" % name)
	super()
	_bind_orb_spawn()
	hover.stats = caster_data.hover
	finder.hover_height = caster_data.hover.hover_height
	finder.leash_range = caster_data.leash_range
	finder.muzzle_height = caster_data.muzzle_height
	finder.target_height = caster_data.target_height
	_los_query = PhysicsRayQueryParameters3D.new()
	_los_query.collision_mask = caster_data.teleport.world_mask
	_body_layer = collision_layer
	_hurtbox_layer = hurtbox.collision_layer
	_charge_orb.visible = false
	_hand_orb.visible = true
	_appear_marker.visible = false
	hurtbox.hurt.connect(_on_hurt_request_teleport)
	died.connect(_on_caster_died)
	if _hover_loop.stream:
		_hover_loop.play()


func _pre_state_update(delta: float) -> void:
	super(delta)
	_teleport_cooldown_left = maxf(_teleport_cooldown_left - delta, 0.0)
	_post_appear_left = maxf(_post_appear_left - delta, 0.0)
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


## Bỏ kết quả đường bắn đã nhớ (vừa dịch chuyển...)
func invalidate_line_of_sight() -> void:
	_los_timer = 0.0


## Hướng ngắm 3D từ nòng tới ngực mục tiêu
func aim_direction() -> Vector3:
	if not has_target():
		return get_facing_direction()
	var aim_point := target.global_position + Vector3.UP * caster_data.target_height
	return (aim_point - _hand_orb.global_position).normalized()


# ---------- Dịch chuyển: điều kiện và bộ đếm ----------

## Điều kiện dịch chuyển do chính quái giữ: đã bắn đủ quả, hoặc vừa bị đánh
func wants_teleport() -> bool:
	if caster_data.teleport_on_hurt and _hurt_pending:
		return true
	return caster_data.casts_before_teleport > 0 and casts_since_teleport >= caster_data.casts_before_teleport


func can_teleport() -> bool:
	return _teleport_cooldown_left <= 0.0


## Hết khoảng hở sau khi hiện ra, được phép niệm
func can_cast() -> bool:
	return _post_appear_left <= 0.0


func notify_cast() -> void:
	casts_since_teleport += 1


## Gọi ngay lúc dịch chuyển xong: reset bộ đếm, bắt đầu hồi chiêu và khoảng hở
func notify_teleported() -> void:
	casts_since_teleport = 0
	_hurt_pending = false
	_teleport_cooldown_left = caster_data.teleport.cooldown
	_post_appear_left = caster_data.teleport.appear_time + caster_data.post_appear_delay
	invalidate_line_of_sight()
	hover.reset_memory()


## Chọn điểm dịch chuyển quanh mục tiêu; không có điểm hợp lệ thì trả về chỗ đứng hiện tại
func find_teleport_point() -> Vector3:
	if not has_target():
		return global_position
	return finder.find_point(target.global_position, home_position, global_position, caster_data.teleport)


# ---------- Niệm và bắn cầu ----------

## Quả cầu nhỏ ở tay lớn dần trong duration giây
func begin_charge(duration: float) -> void:
	if _charge_tween:
		_charge_tween.kill()
	_hand_orb.visible = false
	_charge_orb.visible = true
	_charge_orb.scale = Vector3.ZERO
	_charge_tween = create_tween()
	_charge_tween.tween_property(_charge_orb, "scale", Vector3.ONE, duration)
	_play(_cast_sound)


func cancel_charge() -> void:
	if _charge_tween:
		_charge_tween.kill()
	_charge_orb.visible = false
	_hand_orb.visible = true


func fire_orb(direction: Vector3) -> void:
	var orb := pool.acquire() as SpiritOrb
	# Mỗi quả chỉ nối một lần dù được dùng lại nhiều lần
	if not orb.finished.is_connected(pool.release):
		orb.finished.connect(pool.release)
	orb.launch(data.attack, caster_data.orb, _hand_orb.global_position, direction, self)
	_play(_fire_sound)
	orb_fired.emit(orb)


# ---------- Ẩn / hiện khi dịch chuyển ----------

## Ẩn: không bị đánh, không bị chặn, không bị gió. Gọi lại với false để bật lại (an toàn gọi nhiều lần)
func set_hidden(on: bool) -> void:
	if on == _hidden:
		return
	_hidden = on
	model.visible = not on
	if _blob_shadow:
		_blob_shadow.visible = not on
	# Có thể được gọi trong callback va chạm (bị đánh chen ngang) nên phải hoãn
	hurtbox.set_deferred(&"collision_layer", 0 if on else _hurtbox_layer)
	hurtbox.set_deferred(&"monitorable", not on)
	set_deferred(&"collision_layer", 0 if on else _body_layer)
	if wind_receiver:
		wind_receiver.enabled = not on


func is_hidden() -> bool:
	return _hidden


## Model co lại về một điểm
func play_vanish_fx(duration: float) -> void:
	_kill_model_tween()
	_model_tween = create_tween()
	_model_tween.tween_property(model, "scale", Vector3.ONE * caster_data.teleport.vanish_scale, duration)
	_play(_vanish_sound)


## Model nở ra từ một điểm
func play_appear_fx(duration: float) -> void:
	_kill_model_tween()
	model.scale = Vector3.ONE * caster_data.teleport.vanish_scale
	_model_tween = create_tween()
	_model_tween.tween_property(model, "scale", Vector3.ONE, duration)
	_play(_appear_sound)


func reset_model_fx() -> void:
	_kill_model_tween()
	model.scale = Vector3.ONE


## Dấu hiệu dưới đất ở điểm sắp hiện ra (point là gốc thân sau khi dịch, đã cách đất hover_height)
func show_appear_marker(point: Vector3) -> void:
	if _marker_tween:
		_marker_tween.kill()
	_appear_marker.global_position = Vector3(point.x, point.y - caster_data.hover.hover_height + caster_data.teleport.marker_ground_offset, point.z)
	_appear_marker.scale = Vector3.ONE
	_appear_marker.visible = true


## Dấu hiệu mờ dần (thu nhỏ) rồi ẩn
func fade_appear_marker(duration: float) -> void:
	if _marker_tween:
		_marker_tween.kill()
	_marker_tween = create_tween()
	_marker_tween.tween_property(_appear_marker, "scale", Vector3.ZERO, duration)
	_marker_tween.tween_callback(hide_appear_marker)


func hide_appear_marker() -> void:
	if _marker_tween:
		_marker_tween.kill()
	_appear_marker.visible = false


# ---------- Nội bộ ----------

func _kill_model_tween() -> void:
	if _model_tween:
		_model_tween.kill()


func _play(sound: AudioStreamPlayer3D) -> void:
	if sound.stream:
		sound.play()


func _on_hurt_request_teleport(_info: DamageInfo, _damage_taken: int) -> void:
	_hurt_pending = true


## Quái chết: cầu chưa bị phản tan hết, cầu đã bị phản (đạn của player) bay tiếp độc lập
func _on_caster_died(_enemy: Enemy) -> void:
	for node in pool.get_active():
		var orb := node as SpiritOrb
		if orb.is_reflected():
			pool.detach(orb, get_parent())
		else:
			orb.dissipate()


func _bind_orb_spawn() -> void:
	# Engine theo crystal để quả đang niệm không trượt khỏi đầu trượng khi tay chuyển động.
	var follow := RemoteTransform3D.new()
	follow.name = "OrbSpawnFollow"
	follow.update_position = true
	follow.update_rotation = false
	follow.update_scale = false
	follow.use_global_coordinates = true
	_hand_orb.add_child(follow)
	follow.remote_path = follow.get_path_to(orb_spawn)
	orb_spawn.global_position = _hand_orb.global_position