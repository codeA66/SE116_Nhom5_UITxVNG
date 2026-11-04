class_name ChieftainSummoner
extends Node
## Triệu hồi có giới hạn, tìm nền và chỗ trống trước khi tạo quái thật.

signal summoned(monkeys: Array[MonkeyGrunt])
const GRUNT: PackedScene = preload("res://entities/enemies/wildlife/monkey_grunt/monkey_grunt.tscn")
const BOMBER: PackedScene = preload("res://entities/enemies/wildlife/variants/banana_bomber/banana_bomber.tscn")
@export var summon_count: int = 4
@export var summon_radius: float = 2.8
@export var max_alive_summons: int = 12
var _monkeys: Array[MonkeyGrunt] = []
var _actor: MonkeyChieftain

func _ready() -> void:
	_actor = get_parent() as MonkeyChieftain
	set_process(false)
	set_physics_process(false)

func can_summon() -> bool:
	_prune()
	return _monkeys.size() + summon_count <= max_alive_summons

func summon() -> void:
	# Display đang cập nhật trong tick vật lý; tạo collision ngoài bước flush.
	_spawn.call_deferred()

func _prune() -> void:
	for index: int in range(_monkeys.size() - 1, -1, -1):
		if not is_instance_valid(_monkeys[index]) or _monkeys[index].is_dead(): _monkeys.remove_at(index)

func _spawn() -> void:
	if _actor.is_dead() or not can_summon(): return
	var spawned: Array[MonkeyGrunt] = []
	var space: PhysicsDirectSpaceState3D = _actor.get_world_3d().direct_space_state
	var volume: CapsuleShape3D = CapsuleShape3D.new()
	volume.radius = 0.48
	volume.height = 2.15
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = volume
	query.collision_mask = 263
	query.exclude = [_actor.get_rid()]
	# Hai cấu hình 1+3 và 2+2 có xác suất bằng nhau, chọn một lần cho cả lượt gọi.
	var bomber_count: int = mini(randi_range(1,2),summon_count)
	for index: int in summon_count:
		for attempt: int in 12:
			var angle: float = float(index) * TAU / summon_count + float(attempt) * 0.18
			var radius: float = summon_radius + float(attempt / 4) * 0.65
			var at: Vector3 = _actor.global_position + Vector3(cos(angle), 0, sin(angle)) * radius
			var ground: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2, at - Vector3.UP * 5, 257))
			if ground.is_empty(): continue
			at = ground.position + Vector3.UP * 0.04
			query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.12)
			if not space.intersect_shape(query, 1).is_empty(): continue
			var monkey: MonkeyGrunt = (BOMBER if index < bomber_count else GRUNT).instantiate() as MonkeyGrunt
			_actor.get_parent().add_child(monkey)
			monkey.global_position = at
			monkey.home_position = at
			monkey.reset_physics_interpolation()
			if _actor.has_target(): monkey.receive_rally(_actor.target)
			if _actor.battle_buff_active(): monkey.apply_battle_buff(_actor.battlecry_duration)
			_monkeys.append(monkey)
			spawned.append(monkey)
			break
	summoned.emit(spawned)
