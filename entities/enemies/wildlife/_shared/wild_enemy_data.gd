class_name WildEnemyData
extends EnemyData
## Clip, tỉ lệ root motion và các đòn được cấu hình riêng theo loại quái.
@export var idle_animation: StringName
@export var walk_animation: StringName
@export var run_animation: StringName
@export var hurt_animation: StringName
@export var death_animation: StringName
@export var alert_animation: StringName
@export var model_scale: float = 0.4
@export var skills: Array[EnemySkillData] = []
@export var patrol_arrive_distance: float = 0.35
@export var patrol_timeout: float = 5.0
