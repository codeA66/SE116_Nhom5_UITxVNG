class_name WebPatch
extends Area3D
## Tấm tơ nhện. Nằm trên sàn: player bước vào thì bị dính (WebEntangle: chậm + khóa dash) và tấm tơ bám theo người.
## Đạn tơ trúng player cũng tạo tấm tơ dính luôn (entangle). Không tự tan: chỉ mất khi bị phá.
## Phá: chém kiếm đủ WebData.hits_to_break nhát (tơ có máu riêng), hoặc lửa (BurnableComponent) đốt là tan ngay.
## Lúc dash (bất tử) đi qua tấm tơ trên sàn thì không dính; hết bất tử mà còn đứng trong tơ thì dính.
## Hiệu năng: chỉ dùng signal vào / ra vùng và signal máu / lửa, không có _process. Tấm tơ là vật hiếm (trần max_patches)
## nên dùng instantiate / queue_free thay vì object pool.

signal broken

@export var data: WebData

## Các tấm tơ đang tồn tại, cũ nhất ở đầu: dùng cho trần max_patches
static var _alive: Array[WebPatch] = []

var is_broken: bool = false

var _victim: Player
var _punch: Tween

@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _burnable: BurnableComponent = $BurnableComponent
@onready var _visual: Node3D = $Visual
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _hurt_shape: CollisionShape3D = $HurtboxComponent/CollisionShape3D


func _ready() -> void:
	assert(data != null, "%s chưa gán WebData" % name)
	var cylinder: CylinderShape3D = _shape.shape as CylinderShape3D
	cylinder.radius = data.radius
	(_hurt_shape.shape as CylinderShape3D).radius = data.radius * 0.9
	_visual.scale = Vector3(data.radius, 1.0, data.radius)
	_health.max_health = data.hits_to_break
	_health.heal_full()
	_health.died.connect(_break)
	_hurtbox.hurt.connect(_on_hurt)
	_burnable.ignited.connect(_break)
	body_entered.connect(_on_body_entered)
	# Chỉ chạy khi đã dính người (bám theo)
	set_physics_process(false)
	_alive.append(self)
	_enforce_cap()


func _exit_tree() -> void:
	_alive.erase(self)


## Bị dính vào player này ngay (đạn tơ trúng). Đã dính hoặc đã bị phá thì bỏ qua
func entangle(player: Player) -> void:
	if is_broken or _victim != null:
		return
	_victim = player
	WebEntangle.get_or_create(player).entangle(self)
	set_deferred(&"monitoring", false)
	# Bám theo người bằng cách chép vị trí mỗi khung vật lý (chỉ bật khi đã dính). Không đổi cha: đổi cha
	# làm node rời cây một lúc, WebEntangle tưởng tơ đã mất
	set_physics_process(true)


func is_attached() -> bool:
	return _victim != null


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_victim):
		_break()
		return
	global_position = _victim.global_position


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or is_broken or _victim != null:
		return
	var invincible_left: float = player.get_node("HurtboxComponent").get_invincible_time()
	if invincible_left > 0.0:
		# Đang dash xuyên qua: chờ hết bất tử, còn đứng trong tơ thì mới dính
		get_tree().create_timer(invincible_left + 0.02).timeout.connect(_recheck.bind(player), CONNECT_ONE_SHOT)
		return
	entangle(player)


func _recheck(player: Player) -> void:
	if is_instance_valid(player) and not is_broken and _victim == null and overlaps_body(player):
		_on_body_entered(player)


func _on_hurt(_info: DamageInfo, _damage_taken: int) -> void:
	if is_broken:
		return
	if _punch:
		_punch.kill()
	_visual.scale = Vector3(data.radius, 1.0, data.radius) * 1.15
	_punch = create_tween()
	_punch.tween_property(_visual, ^"scale", Vector3(data.radius, 1.0, data.radius), 0.1)


func _break() -> void:
	if is_broken:
		return
	is_broken = true
	# Bỏ khỏi danh sách ngay: tấm đang co lại chờ xóa không được tính vào trần max_patches
	_alive.erase(self)
	set_physics_process(false)
	if _punch:
		_punch.kill()
	set_deferred(&"monitoring", false)
	_hurtbox.set_deferred(&"monitorable", false)
	_burnable.set_enabled(false)
	broken.emit()
	var tween: Tween = create_tween()
	tween.tween_property(_visual, ^"scale", Vector3(data.radius * 1.2, 0.05, data.radius * 1.2), data.vanish_time).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


## Quá trần thì gỡ tấm cũ nhất chưa dính ai (tấm đang dính người không bị gỡ: sẽ là "gỡ tơ miễn phí")
func _enforce_cap() -> void:
	var over: int = _alive.size() - data.max_patches
	if over <= 0:
		return
	for patch: WebPatch in _alive.duplicate():
		if over <= 0:
			break
		if patch != self and not patch.is_attached() and not patch.is_broken:
			patch._break()
			over -= 1
