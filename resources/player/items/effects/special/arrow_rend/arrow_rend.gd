class_name ArrowRend
extends Node

class Mark:
	var health: HealthComponent
	var remaining: float
	var arrows_per_damage: int
	var arrows: Array[ArrowRendVfx] = []

const MAXIMUM_ARROWS: int = 16
const BOSS_ARROWS_PER_DAMAGE: int = 2

var _player: Player
var _maximum_arrows: int
var _mark_lifetime: float
var _boss_scene_paths: PackedStringArray
var _equipped: bool = false
var _marks: Dictionary[int, Mark] = {}
var _expired: Array[int] = []
var _sword_observers: Dictionary[DamageInfo, Callable] = {}

@onready var _pool: ObjectPool = $ArrowPool


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	for target_id: int in _marks:
		var mark: Mark = _marks[target_id]
		mark.remaining -= delta
		if mark.remaining <= 0.0 or not is_instance_valid(mark.health) or not mark.health.is_inside_tree() or mark.health.is_dead():
			_expired.append(target_id)
	for target_id: int in _expired:
		_release_mark(_marks[target_id])
		_marks.erase(target_id)
	_expired.clear()
	set_physics_process(not _marks.is_empty())


func configure(actor: Player, maximum_arrows: int, lifetime: float, boss_scene_paths: PackedStringArray) -> void:
	_player = actor
	_maximum_arrows = clampi(maximum_arrows, 0, MAXIMUM_ARROWS)
	_mark_lifetime = clampf(lifetime, 0.0, 60.0)
	_boss_scene_paths = boss_scene_paths


func set_equipped(enabled: bool) -> void:
	if _equipped == enabled:
		return
	_equipped = enabled
	if enabled:
		_player.bow_enemy_hit_contact.connect(_on_bow_contact)
		_player.hitbox.damage_prepared.connect(_on_sword_prepared)
		_player.hitbox.damage_checked.connect(_on_sword_checked)
		_player.health.died.connect(_clear_all)
	else:
		_player.bow_enemy_hit_contact.disconnect(_on_bow_contact)
		_player.hitbox.damage_prepared.disconnect(_on_sword_prepared)
		_player.hitbox.damage_checked.disconnect(_on_sword_checked)
		_player.health.died.disconnect(_clear_all)
		_clear_all()


func release() -> void:
	set_equipped(false)
	# Gỡ khỏi cây ngay để đeo lại trong cùng frame không tìm nhầm controller đang chờ xóa.
	get_parent().remove_child(self)
	queue_free()


func _on_bow_contact(hurtbox: HurtboxComponent, position: Vector3, direction: Vector3) -> void:
	if _maximum_arrows == 0 or _mark_lifetime <= 0.0 or not is_instance_valid(hurtbox.health) or hurtbox.health.is_dead():
		return
	var actor: Node3D = hurtbox.owner as Node3D
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return
	# Dùng máu làm khóa để các hurtbox chung của cùng một boss dùng chung số tên.
	var target_id: int = hurtbox.health.get_instance_id()
	var mark: Mark = _marks.get(target_id) as Mark
	if mark == null:
		mark = Mark.new()
		mark.health = hurtbox.health
		mark.arrows_per_damage = BOSS_ARROWS_PER_DAMAGE if actor.scene_file_path in _boss_scene_paths else 1
		_marks[target_id] = mark
		set_physics_process(true)
	mark.remaining = _mark_lifetime
	if mark.arrows.size() >= _maximum_arrows:
		return
	var visual: ArrowRendVfx
	if _pool.get_active_count() < _pool.initial_size:
		visual = _pool.acquire() as ArrowRendVfx
		if not visual.finished.is_connected(_pool.release):
			visual.finished.connect(_pool.release)
		var character: Character = actor as Character
		var anchor: Node3D = character.model if character and is_instance_valid(character.model) else actor
		var shape: Node3D = hurtbox.get_node_or_null(^"CollisionShape3D") as Node3D
		var torso: Vector3 = shape.global_position if shape else position
		visual.pin(anchor, position, torso, direction, mark.arrows.size())
	mark.arrows.append(visual)


func _on_sword_prepared(hurtbox: HurtboxComponent, info: DamageInfo) -> void:
	if not is_instance_valid(hurtbox.health) or hurtbox.health.is_dead():
		return
	var target_id: int = hurtbox.health.get_instance_id()
	var mark: Mark = _marks.get(target_id) as Mark
	if mark == null or mark.remaining <= 0.0 or info.amount <= 0:
		return
	var weapon: WeaponData = _player.get_weapon()
	if weapon == null or weapon.slot != WeaponData.Slot.SWORD or not weapon.combo.has(info.attack):
		return
	@warning_ignore("integer_division")
	var extra_damage: int = mark.arrows.size() / mark.arrows_per_damage
	if extra_damage == 0:
		return
	# Tính vào cùng nhát kiếm để i-frame, khiên và các ngưỡng máu boss xử lý một lần.
	info.amount += extra_damage
	var observer: Callable = _on_sword_hurt.bind(info, target_id, extra_damage * mark.arrows_per_damage, hurtbox)
	_sword_observers[info] = observer
	hurtbox.hurt.connect(observer)


func _on_sword_checked(hurtbox: HurtboxComponent, info: DamageInfo) -> void:
	var observer: Callable = _sword_observers.get(info, Callable())
	if not observer.is_valid():
		return
	_sword_observers.erase(info)
	if is_instance_valid(hurtbox):
		hurtbox.hurt.disconnect(observer)


func _on_sword_hurt(info: DamageInfo, damage_taken: int, expected: DamageInfo, target_id: int, spent: int,
		hurtbox: HurtboxComponent) -> void:
	if info != expected or damage_taken <= 0:
		return
	var mark: Mark = _marks.get(target_id) as Mark
	if mark == null:
		return
	var shape: Node3D = hurtbox.get_node_or_null(^"CollisionShape3D") as Node3D
	var impact_position: Vector3 = shape.global_position if shape else hurtbox.global_position
	var flash_count: int = spent
	for index: int in range(mini(mark.arrows.size(), spent)):
		var visual: ArrowRendVfx = mark.arrows.pop_back()
		if visual:
			visual.retract(-info.direction, impact_position, flash_count)
			flash_count = 0
	if mark.arrows.is_empty():
		_marks.erase(target_id)
		set_physics_process(not _marks.is_empty())


func _release_mark(mark: Mark) -> void:
	for visual: ArrowRendVfx in mark.arrows:
		if visual:
			_pool.release(visual)


func _clear_all() -> void:
	_marks.clear()
	_pool.release_all()
	set_physics_process(false)
