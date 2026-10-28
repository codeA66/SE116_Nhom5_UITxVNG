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
@export_group("Cooldown Approach")
@export var advance_on_cooldown: bool = false
@export_range(0.1, 1.0) var cooldown_walk_speed_scale: float = 0.28
@export var cooldown_run_distance: float = 4.5
@export var approach_stop_distance: float = 1.1
## Đang về nhà vẫn tự vệ khi player áp sát, kể cả bị vật cản chặn đường về.
@export var close_defense_range: float = 2.5
