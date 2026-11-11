class_name FireSpider
extends Enemy
## Nhện Lửa: quái thường của map Lửa. Đuổi theo player (SpiderChase), vào tầm cắn thì cắn nhanh (Attack dùng chung),
## ngoài tầm cắn thì dùng kỹ năng: nhảy vồ (SpiderPounce) và phun tơ làm player chậm + khóa dash tới khi xé / đốt tơ (SpiderWebShot).
## Kháng lửa như các quái map Lửa khác (chỉnh trong FireSpiderData).
## Script này là API mỏng cho các state: chọn kỹ năng, bắn đạn tơ, vùng sát thương lúc đáp.
## Thêm kỹ năng mới = thêm node state kế thừa SpiderSkill vào StateMachine, không sửa file này.

signal web_fired(bolt: WebBolt)
signal pounce_landed(center: Vector3, hit_count: int)

var spider_data: FireSpiderData
## Kỹ năng chủ động, đã xếp theo priority
var skills: Array[SpiderSkill] = []

var _anim_player: AnimationPlayer

@onready var _web_pool: ObjectPool = $WebPool
@onready var _impact: ExplosionComponent = $LandImpact


func _ready() -> void:
	spider_data = data as FireSpiderData
	assert(spider_data != null, "%s: EnemyData phải là FireSpiderData" % name)
	super()
	_anim_player = $AnimationPlayer
	hurtbox.resistances[DamageInfo.Type.FIRE] = spider_data.fire_damage_multiplier
	var burnable: BurnableComponent = get_node_or_null(^"BurnableComponent") as BurnableComponent
	if burnable and spider_data.fire_immune:
		burnable.set_enabled(false)
	_impact.attack = spider_data.pounce_attack
	_impact.radius = spider_data.pounce_radius
	_impact.exploded.connect(func(center: Vector3, hits: int) -> void: pounce_landed.emit(center, hits))
	for child: Node in state_machine.get_children():
		if child is SpiderSkill:
			skills.append(child as SpiderSkill)
	skills.sort_custom(func(a: SpiderSkill, b: SpiderSkill) -> bool: return a.priority < b.priority)
	died.connect(_on_spider_died)


func _pre_state_update(delta: float) -> void:
	super(delta)
	for skill: SpiderSkill in skills:
		skill.tick(delta)


## Kỹ năng đầu tiên (theo priority) dùng được lúc này; null nếu không có
func pick_skill() -> SpiderSkill:
	for skill: SpiderSkill in skills:
		if skill.can_use():
			return skill
	return null


## Độ dài clip (s); 0 nếu model chưa có clip đó
func get_animation_length(anim_name: StringName) -> float:
	return _anim_player.get_animation(anim_name).length if _anim_player.has_animation(anim_name) else 0.0


# ---------- Phun tơ ----------

func get_muzzle_position() -> Vector3:
	return global_position + get_facing_direction() * 0.5 + Vector3.UP * spider_data.web_muzzle_height


## Hướng ngắm 3D từ miệng phun tới ngực mục tiêu
func web_aim_direction() -> Vector3:
	if not has_target():
		return get_facing_direction()
	var aim_point: Vector3 = target.global_position + Vector3.UP * spider_data.web_target_height
	return (aim_point - get_muzzle_position()).normalized()


func shoot_web(direction: Vector3) -> WebBolt:
	var bolt: WebBolt = _web_pool.acquire() as WebBolt
	# Mỗi quả chỉ nối một lần dù được dùng lại nhiều lần
	if not bolt.finished.is_connected(_web_pool.release):
		bolt.finished.connect(_web_pool.release)
	bolt.launch(spider_data.web, get_muzzle_position(), direction)
	web_fired.emit(bolt)
	return bolt


# ---------- Nhảy vồ ----------

## Vùng sát thương quanh chỗ đáp (chỉ trúng player, xem hurtbox_mask của LandImpact)
func land_impact() -> int:
	_impact.global_position = global_position
	return _impact.explode(self)


# ---------- Nội bộ ----------

## Nhện chết: đạn tơ đang bay tan hết, không tạo tơ
func _on_spider_died(_enemy: Enemy) -> void:
	for node: Node in _web_pool.get_active():
		(node as WebBolt).dissipate()
