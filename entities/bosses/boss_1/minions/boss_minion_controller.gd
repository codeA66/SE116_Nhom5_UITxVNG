class_name BossMinionController
extends Node
## Sở hữu và thu dọn quái triệu hồi theo từng instance boss.

@export_group("Minion Scenes")
@export var grunt_scene: PackedScene = preload("res://entities/enemies/palace/enemy_1/enemy_1.tscn")
@export var shield_bearer_scene: PackedScene = preload("res://entities/enemies/palace/shield_bearer/shield_bearer.tscn")
@export var wisp_caster_scene: PackedScene = preload("res://entities/enemies/palace/wisp_caster/wisp_caster.tscn")

@export_group("Minion Summon - Phase 2 (50% HP)")
## Số lượng lính kiếm summon ở Phase 2
@export var phase2_grunt_count: int = 1
## Số lượng lính khiên summon ở Phase 2 (chắn đường trước mặt)
@export var phase2_shield_count: int = 1
## Số lượng pháp sư summon ở Phase 2
@export var phase2_caster_count: int = 0

@export_group("Minion Summon - Phase 3 (20% HP)")
## Số lượng lính kiếm summon ở Phase 3
@export var phase3_grunt_count: int = 2
## Số lượng lính khiên summon ở Phase 3
@export var phase3_shield_count: int = 1
## Số lượng pháp sư summon ở Phase 3
@export var phase3_caster_count: int = 1

@export_group("Spawn")
## Bán kính vòng tròn quanh Boss để xuất hiện quái phụ
@export var minion_spawn_radius: float = 4.5

var _spawned_minions: Array[Node] = []
var _boss: Boss1

func _ready() -> void:
	_boss = owner as Boss1

func summon(phase: int) -> void:
	var grunts: int = 0
	var shields: int = 0
	var casters: int = 0
	
	if phase == 2:
		grunts = phase2_grunt_count
		shields = phase2_shield_count
		casters = phase2_caster_count
	elif phase == 3:
		grunts = phase3_grunt_count
		shields = phase3_shield_count
		casters = phase3_caster_count
	
	var scenes_to_spawn: Array[PackedScene] = []
	if grunt_scene:
		for i in grunts:
			scenes_to_spawn.append(grunt_scene)
	if shield_bearer_scene:
		for i in shields:
			scenes_to_spawn.append(shield_bearer_scene)
	if wisp_caster_scene:
		for i in casters:
			scenes_to_spawn.append(wisp_caster_scene)
	
	var total: int = scenes_to_spawn.size()
	if total == 0:
		return
	
	var parent_node: Node = _boss.get_parent()
	if parent_node == null:
		return
	
	var angle_step: float = TAU / float(total)
	var base_angle: float = _boss.model.rotation.y if _boss.model else 0.0
	var fx: Node = get_node_or_null(^"/root/CombatFx")
	
	for i in total:
		var scene: PackedScene = scenes_to_spawn[i]
		var minion := scene.instantiate() as Node3D
		if minion == null:
			continue
		
		var angle: float = base_angle + float(i) * angle_step + randf_range(-0.15, 0.15)
		var offset: Vector3 = Vector3(sin(angle), 0.0, cos(angle)) * minion_spawn_radius
		var spawn_pos: Vector3 = _boss.global_position + offset
		
		parent_node.add_child(minion)
		minion.global_position = spawn_pos
		_spawned_minions.append(minion)
		
		minion.tree_exiting.connect(_on_minion_removed.bind(minion))
		
		if fx and fx.has_method(&"spawn_hit"):
			fx.spawn_hit(spawn_pos + Vector3(0, 1.0, 0), Vector3.UP)


func _on_minion_removed(minion: Node) -> void:
	_spawned_minions.erase(minion)


func get_spawned_count() -> int:
	return _spawned_minions.size()



func clear() -> void:
	# Tiêu diệt toàn bộ quái phụ được triệu hồi khi Boss bị hạ gục
	for minion in _spawned_minions.duplicate():
		if is_instance_valid(minion):
			var health_comp: HealthComponent = minion.get_node_or_null(^"HealthComponent") as HealthComponent
			if health_comp and not health_comp.is_dead():
				health_comp.take_damage(health_comp.current_health)
			elif minion.has_method(&"queue_free"):
				minion.queue_free()
	_spawned_minions.clear()
	
