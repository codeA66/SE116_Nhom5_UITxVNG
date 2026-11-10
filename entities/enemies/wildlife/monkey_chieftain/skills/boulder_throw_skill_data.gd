class_name BoulderThrowSkillData
extends EnemySkillData
## Dùng chung thời gian pose, vật trên tay, quỹ đạo và vòng cảnh báo.

@export var release_time: float = 1.35
@export var rock_radius: float = 0.72
@export var impact_radius: float = 1.5
@export var flight_time: float = 1.15
@export var arc_height: float = 3.8
@export var shard_count: int = 7
@export var shard_radius: float = 0.72
## Bán kính mảnh nhìn thấy/va chạm theo đá chính; AoE mảnh chỉnh riêng bằng shard_radius.
@export_range(0.1, 0.8, 0.05) var shard_size_ratio: float = 0.45
@export var shard_ring_min: float = 3.7
@export var shard_ring_max: float = 5.8
@export var shard_flight_time: float = 1.2
@export var shard_arc_height: float = 5.5
