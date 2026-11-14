class_name Breakable
extends StaticBody3D
## Vật phá được kiểu Death's Door: mỗi nhát trúng rung + loé, đủ max_hits thì vỡ, sau respawn_time mọc lại.
## Chém cận chiến trúng thì player tự nạp năng lượng (Attack._on_hit); tên / kỹ năng gió chỉ trừ máu, không nạp.
## Hình nằm dưới Visual, mảnh vỡ dựng sẵn dưới Debris (dùng lại mỗi lần vỡ, không tạo node lúc chạy).
## Hiệu năng: không có _process; mọi chuyển động bằng tween, vùng chặn mọc lại chỉ bật khi đang chờ.

signal broken
signal respawned

@export var data: BreakableData
## Vật liệu phủ lúc loé trúng đòn (dùng chung mọi vật, không duplicate)
@export var flash_material: Material

var is_broken: bool = false

var _shake_tween: Tween
var _debris_tween: Tween
var _debris_rest: Array[Transform3D] = []
var _meshes: Array[GeometryInstance3D] = []

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual
@onready var _debris: Node3D = $Debris
@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _receiver: WindReceiverComponent = $WindReceiver
@onready var _blocker: Area3D = $RespawnBlocker
@onready var _respawn_timer: Timer = $RespawnTimer
@onready var _hit_dust: GPUParticles3D = $HitDust
@onready var _break_dust: GPUParticles3D = $BreakDust
@onready var _hit_sound: AudioStreamPlayer3D = $HitSound
@onready var _break_sound: AudioStreamPlayer3D = $BreakSound


func _ready() -> void:
	# Không phải mục tiêu chiến đấu: bỏ khỏi nhóm soft-lock để kiếm không tự nhắm vào thùng
	_hurtbox.remove_from_group(HurtboxComponent.GROUP)
	# Vật đứng yên: bộ nhận gió chỉ để kỹ năng gió tìm thấy và trừ máu, không cần quét vùng gió
	_receiver.set_physics_process(false)
	_health.max_health = data.max_hits if data else 1
	_health.heal_full()
	# Cache mesh một lần: loé trúng đòn không duyệt cây mỗi nhát
	for mesh: Node in _visual.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(mesh as GeometryInstance3D)
	for child in _debris.get_children():
		_debris_rest.append((child as Node3D).transform)
	# Mảnh vỡ nhỏ, bay nhanh: không cần đổ bóng
	for mesh: Node in _debris.find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debris.hide()
	_blocker.monitoring = false
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_on_respawn_timer)
	_hurtbox.hurt.connect(_on_hurt)
	_health.died.connect(_on_died)


func _on_hurt(info: DamageInfo, _damage_taken: int) -> void:
	if is_broken or _health.is_dead():
		return
	_play_hit(info)


func _on_died() -> void:
	if is_broken:
		return
	is_broken = true
	_set_solid(false)
	_play_break()
	broken.emit()
	if data and data.respawn_time > 0.0:
		_respawn_timer.start(data.respawn_time)


func _on_respawn_timer() -> void:
	# Player đang đứng chỗ thùng: chờ đi ra rồi mới mọc, không kẹt player trong va chạm
	_blocker.monitoring = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _blocker.has_overlapping_bodies():
		_blocker.body_exited.connect(_on_blocker_exited)
		return
	_respawn()


func _on_blocker_exited(_body: Node3D) -> void:
	if _blocker.has_overlapping_bodies():
		return
	_blocker.body_exited.disconnect(_on_blocker_exited)
	_respawn()


func _respawn() -> void:
	_blocker.set_deferred(&"monitoring", false)
	is_broken = false
	_health.heal_full()
	# Mọc lại nhanh hơn lúc mảnh còn bay (respawn_time < debris_time): dừng tween mảnh cũ
	_kill_debris_tween()
	_debris.hide()
	_visual.show()
	_visual.scale = Vector3.ONE * 0.2
	create_tween().tween_property(_visual, ^"scale", Vector3.ONE, data.respawn_grow_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_set_solid(true)
	respawned.emit()


func _set_solid(solid: bool) -> void:
	_shape.set_deferred(&"disabled", not solid)
	_hurtbox.set_deferred(&"monitorable", solid)
	_receiver.set_deferred(&"monitorable", solid)
	_receiver.enabled = solid


func _play_hit(info: DamageInfo) -> void:
	if _hit_sound.stream:
		_hit_sound.play()
	_hit_dust.restart()
	ScreenShake.add_trauma(data.hit_trauma)
	# Rung theo hướng đòn rồi về chỗ cũ
	var dir := info.direction if info.direction.length_squared() > 0.0 else Vector3.FORWARD
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_visual.position = Vector3.ZERO
	_shake_tween = create_tween()
	_shake_tween.tween_property(_visual, ^"position", dir * data.shake_offset, data.shake_time * 0.25)
	_shake_tween.tween_property(_visual, ^"position", -dir * data.shake_offset * 0.5, data.shake_time * 0.35)
	_shake_tween.tween_property(_visual, ^"position", Vector3.ZERO, data.shake_time * 0.4)
	_set_flash(true)
	get_tree().create_timer(data.flash_time).timeout.connect(_set_flash.bind(false))


func _play_break() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_set_flash(false)
	_visual.hide()
	_visual.position = Vector3.ZERO
	if _break_sound.stream:
		_break_sound.play()
	_break_dust.restart()
	ScreenShake.add_trauma(data.break_trauma)
	_debris.show()
	_kill_debris_tween()
	var tween := create_tween().set_parallel()
	_debris_tween = tween
	var count := _debris.get_child_count()
	for i in count:
		var chunk := _debris.get_child(i) as Node3D
		var rest := _debris_rest[i]
		chunk.transform = rest
		# Mảnh văng toả ra từ tâm theo vị trí đặt sẵn, rơi xuống sàn rồi thu nhỏ biến mất
		var out := Vector3(rest.origin.x, 0.0, rest.origin.z)
		out = out.normalized() if out.length_squared() > 0.001 else Vector3.RIGHT.rotated(Vector3.UP, TAU * i / count)
		var land := Vector3(rest.origin.x, 0.05, rest.origin.z) + out * data.debris_reach
		var t := data.debris_time
		tween.tween_property(chunk, ^"position:x", land.x, t * 0.6)
		tween.tween_property(chunk, ^"position:z", land.z, t * 0.6)
		tween.tween_property(chunk, ^"position:y", rest.origin.y + data.debris_lift, t * 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(chunk, ^"position:y", land.y, t * 0.35).set_delay(t * 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(chunk, ^"rotation", rest.basis.get_euler() + Vector3(out.z, 0.0, -out.x) * 4.0, t * 0.6)
		tween.tween_property(chunk, ^"scale", Vector3.ZERO, t * 0.4).set_delay(t * 0.6)
	tween.chain().tween_callback(_debris.hide)


func _kill_debris_tween() -> void:
	if _debris_tween and _debris_tween.is_valid():
		_debris_tween.kill()


func _set_flash(on: bool) -> void:
	for mesh in _meshes:
		mesh.material_overlay = flash_material if on else null
