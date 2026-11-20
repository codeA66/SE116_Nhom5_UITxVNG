class_name PyralonData
extends WildEnemyData
## Cân bằng từng phần nhịp đánh của Pyralon.

@export_group("AI")
@export var chase_pause: float = 1.45
@export var rear_range: float = 4.0
@export var rear_half_angle: float = 60.0
@export var rear_lock_time: float = 0.65

@export_group("Slam")
@export var slam_takeoff: float = 0.68
@export var slam_impact: float = 2.25
@export_range(4, 48, 1) var radial_count: int = 30
@export var radial_radius: float = 2.45
@export var radial_speed_ratio: float = 3.0
@export var fissure_speed: float = 20.0
@export var fissure_max_time: float = 3.0
@export var fissure_lock_time: float = 0.50
@export var geyser_radius: float = 3.10

@export_group("Rear Slash")
@export var arc_speed_ratio: float = 0.90
@export var arc_width: float = 7.2
@export var arc_range: float = 15.0
@export_range(1, 8, 1) var arc_gold_count: int = 5

@export_group("Barrage")
@export var barrage_duration: float = 6.0
@export var barrage_shot_interval: float = 0.085
@export var barrage_speed_ratio: float = 4.2
@export var barrage_lead_time: float = 0.0
@export var barrage_cluster_radius: float = 0.75
@export var barrage_track_speed: float = 7.5
@export_range(1, 24, 1) var barrage_gold_count: int = 20
@export var spread_radius: float = 15.0
@export var gold_spacing: float = 2.3

@export_group("Feathers")
@export var gold_hover_height: float = 0.80
@export var gold_lifetime: float = 28.0
@export var gold_trigger_range: float = 1.60
@export var gold_blast_radius: float = 2.2
@export var gold_hover_warning_time: float = 0.70
@export var gold_warning_time: float = 0.50
@export var gold_chase_time: float = 3.0
@export var gold_chase_speed: float = 6.4
@export var command_interval: float = 0.68
@export var feather_damage: int = 1
