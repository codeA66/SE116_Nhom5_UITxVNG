class_name Enemy
extends Character
## Lớp cơ sở cho mọi quái. Lo: thông số từ EnemyData, mục tiêu (player), đòn đánh, nháy sáng khi trúng đòn,
## nháy báo trước khi ra đòn, chết vì hết máu / vực / gai. Hành vi nằm ở các state (entities/enemies/_base/states).
## Quái mới: New Inherited Scene từ enemy.tscn, gán EnemyData, thêm model vào Model/Visual, thêm state riêng nếu cần.

signal died(enemy: Enemy)

@export var data: EnemyData
## Phủ lên model khi bị đánh trúng
@export var hit_flash_material: Material
@export var hit_flash_time: float = 0.1
## Phủ lên model trong lúc lấy đà ra đòn: báo trước cho người chơi né
@export var telegraph_material: Material

@export_group("Behaviour States")
## Tên node state dùng khi có mục tiêu. Quái có cách tiếp cận riêng (giữ khoảng cách, bay vòng...)
## thêm node state mới vào StateMachine rồi đổi tên ở đây, không sửa state dùng chung
@export var chase_state: StringName = &"Chase"
## Tên node state ra đòn (cận chiến, bắn, lao húc... mỗi kiểu một state)
@export var attack_state: StringName = &"Attack"

## Mục tiêu đang đuổi (null = không đuổi)
var target: Node3D
## Đòn gần nhất trúng quái, state Hurt đọc để đẩy lùi
var last_hit: DamageInfo
var home_position: Vector3
var _attack_cooldown_left: float = 0.0
var _flash_tween: Tween

@onready var hitbox: HitboxComponent = $Model/Hitbox
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var sensor: EnemySensor = $EnemySensor


func _ready() -> void:
	assert(data != null, "%s chưa gán EnemyData" % name)
	movement = data.movement
	super()
	home_position = global_position
	health.max_health = data.max_health
	health.heal_full()
	sensor.radius = data.detect_range
	hitbox.set_reach(data.hitbox_reach)
	if wind_receiver:
		wind_receiver.wind_multiplier = data.wind_multiplier
		wind_receiver.pushed.connect(_on_wind_pushed)
	sensor.target_entered.connect(_on_target_entered)
	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)


func _pre_state_update(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)


# ---------- Mục tiêu ----------

func has_target() -> bool:
	return is_instance_valid(target)


## Khoảng cách ngang tới mục tiêu (bỏ chênh lệch độ cao)
func distance_to_target() -> float:
	if not has_target():
		return INF
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.length()


func direction_to_target() -> Vector3:
	if not has_target():
		return Vector3.ZERO
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.normalized()


func distance_from_home() -> float:
	var offset := global_position - home_position
	offset.y = 0.0
	return offset.length()


func forget_target() -> void:
	target = null


## Nhận lại mục tiêu cảm biến đang thấy. Cảm biến chỉ báo lúc player vừa bước vào vùng, nên nếu quái bỏ
## mục tiêu khi player vẫn đứng trong vùng thì không có lần báo nào nữa và quái đứng im mãi
func reacquire_target() -> void:
	if not has_target() and not is_dead() and is_instance_valid(sensor.target):
		target = sensor.target


## Mục tiêu đã ra quá xa, hoặc quái bị kéo quá xa chỗ xuất phát
func should_give_up_chase() -> bool:
	return not has_target() or distance_to_target() > data.lose_range or distance_from_home() > data.leash_range


# ---------- Đòn đánh ----------

func can_attack() -> bool:
	return data.attack != null and _attack_cooldown_left <= 0.0 and distance_to_target() <= data.attack_range


func start_attack_cooldown() -> void:
	_attack_cooldown_left = data.attack_cooldown


func set_telegraph(on: bool) -> void:
	_set_overlay(telegraph_material if on else null)


# ---------- Animation: bỏ qua nếu model chưa có clip (quái dùng hình tạm) ----------

func play_anim(anim_name: StringName) -> void:
	if _anim.has_animation(anim_name):
		super(anim_name)


func play_action(anim_name: StringName, speed: float = 1.0, blend: float = -1.0) -> void:
	if _anim.has_animation(anim_name):
		super(anim_name, speed, blend)


# ---------- Chết vì môi trường (KillZone / gai gọi tới) ----------

func on_kill_zone_entered() -> void:
	_die_now()


func on_lethal_zone_entered(_red_flash: bool = false) -> void:
	_die_now()


func is_dead() -> bool:
	return health.is_dead()


## Ngủ yên (đứng sẵn trong phòng, trận chưa bắt đầu): tắt cảm biến nên không tự lao vào player.
## Bị đánh vẫn phản ứng như thường. Gọi trễ vì có thể chạy trong callback vật lý (player bước vào Trigger)
func set_dormant(dormant: bool) -> void:
	sensor.set_deferred(&"monitoring", not dormant)


# ---------- Nội bộ ----------

func _die_now() -> void:
	if health.is_dead():
		return
	health.take_damage(health.current_health)


func _on_target_entered(body: Node3D) -> void:
	if not is_dead():
		target = body


func _on_hurt(info: DamageInfo, _damage_taken: int) -> void:
	last_hit = info
	# Bị đánh từ xa (tên bắn, sau lưng) thì quay sang đuổi người đánh
	if info.source is Node3D and target == null:
		target = info.source as Node3D
	_flash_hit()
	if is_dead():
		return
	if data.stagger_on_hit:
		state_machine.transition_to(EnemyState.HURT)
	else:
		# Quái có giáp: không khựng, chỉ bị đẩy nhẹ
		velocity += info.knockback * 0.3


func _on_wind_pushed(_impulse: Vector3) -> void:
	if is_dead() or not data.stagger_on_wind or is_zero_approx(data.wind_multiplier):
		return
	state_machine.transition_to(EnemyState.BLOWN)


func _on_died() -> void:
	state_machine.transition_to(EnemyState.DEAD)
	died.emit(self)


func _flash_hit() -> void:
	if hit_flash_material == null:
		return
	_set_overlay(hit_flash_material)
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(hit_flash_time)
	_flash_tween.tween_callback(_set_overlay.bind(null))


func _set_overlay(mat: Material) -> void:
	for node in model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_overlay = mat
