class_name SabretoothData
extends WildEnemyData
## Nhịp săn và khoảng hở dùng riêng cho boss hổ.

@export_group("Phase One")
@export var attack_interval: float = 4.0
@export var close_range: float = 3.6
@export var far_pounce_range: Vector2 = Vector2(8.0, 18.0)
@export var near_pounce_range: float = 4.8
@export var run_distance: float = 6.0
@export var gait_hysteresis: float = 0.7
@export var stalk_stop_distance: float = 2.7
@export var side_attack_range: Vector2 = Vector2(2.8, 4.2)
@export var side_angle: float = 45.0
@export var rear_angle: float = 135.0
@export var turn_snap_angle: float = 22.0
@export var turn_clips: Array[StringName] = [&"TurnLeft", &"LeftTurn", &"TurnRight", &"45TurnLeft", &"Spin180", &"Spin180Right", &"Slow180", &"180RIght"]
@export var reaction_clips: Array[StringName] = [&"Backing", &"Cowering", &"Cowering2", &"Agitated", &"PissedOff", &"PissedOff2"]
@export var backup_speed: float = 3.0
@export var backup_distance: float = 2.2
@export var backup_playback: float = 1.25
@export_range(1.0, 5.0, 0.1) var warning_duration: float = 2.6
@export var warning_bridge: float = 0.25
@export var warning_commit_before_end: float = 0.18
@export var ready_bridge: float = 0.18
@export var recent_attack_time: float = 0.55
@export var attack_aim_lock: float = 0.25
@export var pounce_travel: float = 15.3
@export var pounce_speed: float = 24.0
@export_range(1.0, 3.0, 0.05) var pounce_animation_rate: float = 1.35
@export var pounce_landing_gap: float = 2.7

@export_group("Phase Two")
@export var phase_two_health: int = 100
@export var beam_charge_time: float = 3.0
@export var beam_lock_time: float = 1.0
@export var beam_duration: float = 5.0
@export var beam_range: float = 100.0
@export var beam_radius: float = 0.95
@export var beam_tick: float = 0.75
@export var beam_damage: int = 1
@export var beam_tracking_ratio: float = 0.95
@export var beam_recoil: float = 0.55
@export var beam_ball_radius: float = 1.0
@export var beam_muzzle_offset: float = 2.25
@export var scorch_duration: float = 6.0
@export var finale_backup_distance: float = 2.2
@export var finale_backup_speed: float = 3.0
@export var finale_pounce_speed: float = 24.0
@export var finale_pounce_height: float = 2.8
@export var finale_pounce_range: float = 20.0
@export var finale_warning_time: float = 1.0
@export var finale_radius: float = 8.4
@export var finale_damage: int = 1
@export var finale_fade_time: float = 2.0

@export_group("Hunting")
@export var stalk_speed: float = 1.8
@export var trot_speed: float = 3.5
@export var sprint_distance: float = 8.5
@export var trot_distance: float = 5.8
@export var circle_radius: float = 4.7
@export var circle_time: Vector2 = Vector2(0.7, 1.5)
@export var decision_interval: float = 0.25
@export var turn_threshold: float = 65.0
@export var phase_two_pace: float = 1.22

@export_group("Rest")
@export var rest_interval: Vector2 = Vector2(3.5, 6.0)

@export_group("Evasion")
@export var dodge_distance: float = 2.1
@export var dodge_range: float = 4.0
@export var dodge_cooldown: float = 6.0
@export_range(0.0, 1.0) var dodge_chance: float = 0.42
@export var clearance: float = 0.28

@export_group("Animation")
@export_range(0.05, 0.5, 0.01) var bridge_duration: float = 0.20
