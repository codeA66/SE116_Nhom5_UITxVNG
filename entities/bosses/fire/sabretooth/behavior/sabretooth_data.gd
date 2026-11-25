class_name SabretoothData
extends WildEnemyData
## Nhịp săn và khoảng hở dùng riêng cho boss hổ.

@export_group("Phase One")
@export var attack_interval: float = 4.0
@export var stand_pause: float = 2.0
@export var close_range: float = 3.6
@export var far_pounce_range: Vector2 = Vector2(8.0, 18.0)
@export var near_pounce_range: float = 4.8
@export var run_distance: float = 6.0
@export var gait_hysteresis: float = 0.7
@export var stalk_stop_distance: float = 2.7
@export var side_attack_range: Vector2 = Vector2(1.0, 4.6)
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
@export var phase_two_health: int = 25
@export var beam_charge_time: float = 3.0
@export var beam_lock_time: float = 1.0
@export var beam_duration: float = 8.0
@export var beam_range: float = 100.0
@export var beam_radius: float = 0.95
@export var beam_tick: float = 0.75
@export var beam_damage: int = 1
@export var beam_tracking_start_ratio: float = 0.75
@export var beam_tracking_max_ratio: float = 1.25
@export var beam_reverse_pause: float = 0.20
@export var beam_travel_time: float = 0.50
@export var beam_recoil: float = 0.55
@export var beam_ball_radius: float = 1.0
@export var beam_muzzle_offset: float = 2.25
@export var beam_barrier_radius: float = 6.0
@export var beam_barrier_height: float = 3.2
@export var beam_barrier_draw_time: float = 1.65
@export var beam_barrier_rise_time: float = 1.15
@export var beam_barrier_fade_time: float = 0.45
@export var beam_push_radius: float = 6.8
@export var beam_push_speed: float = 24.0
@export var scorch_duration: float = 6.0
@export var finale_backup_distance: float = 2.2
@export var finale_backup_speed: float = 3.0
@export var finale_pounce_speed: float = 24.0
@export var finale_pounce_height: float = 2.8
@export var finale_pounce_range: float = 20.0
@export var dive_duration: float = 0.62
@export var finale_warning_time: float = 1.0
@export var finale_radius: float = 10.0
@export var finale_damage: int = 1
@export var finale_fade_time: float = 2.0
@export_range(1, 10, 1) var blitz_count: int = 5
@export var blitz_warn_time: float = 0.70
@export var blitz_dash_time: float = 0.22
@export var blitz_gap_time: float = 0.28
@export var blitz_lane_length: float = 18.0
@export var blitz_lane_radius: float = 1.65
@export var blitz_damage: int = 1
@export var reform_duration: float = 1.50
@export var phase_two_skill_gap: float = 2.0
@export var phase_two_rest_speed: float = 2.6
@export var phase_two_hunt_duration: float = 9.0
@export var phase_two_down_time: float = 4.0
@export var phase_two_getup_speed: float = 0.55
@export var death_revert_duration: float = 1.65
@export_range(0.1, 1.0, 0.05) var true_death_time_scale: float = 0.5

@export_group("Phase Two Fang Snap & Cross Claw")
@export var fang_snap_speed: float = 4.6
@export var fang_snap_homing_duration: float = 9.0
@export var fang_snap_turn_rate: float = 3.2
@export var fang_snap_wind_push: float = 19.0
@export var fang_snap_scale: float = 1.85
@export var fang_snap_range: float = 48.0
@export var fang_snap_damage: int = 2
@export var fang_snap_wall_stain_time: float = 8.0
@export_range(1, 5, 1) var cross_claw_repeats: int = 2
@export var cross_claw_warn_time: float = 0.70
@export var cross_claw_pause_time: float = 0.45
@export var cross_claw_length: float = 7.6
@export var cross_claw_width: float = 4.2
@export var cross_claw_swipe_damage: int = 2
@export var cross_claw_fissure_duration: float = 30.0
@export var cross_claw_erupt_interval: float = 5.0
@export var cross_claw_erupt_damage: int = 1

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
