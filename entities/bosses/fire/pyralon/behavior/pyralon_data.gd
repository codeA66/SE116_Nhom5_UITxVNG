class_name PyralonData
extends WildEnemyData
## Cân bằng từng phần nhịp đánh của Pyralon.

@export_group("AI")
@export var chase_pause: float = 1.45
@export var rear_check_pause: float = 1.5
@export var rear_detect_length: float = 18.0
@export var rear_detect_half_width: float = 8.0
@export var rear_min_back_offset: float = 2.4
@export var rear_lock_time: float = 0.65

@export_group("Phase Two")
@export var phase_two_health: int = 44
@export var transform_duration: float = 4.4
@export var phase_two_down_time: float = 3.0
@export var phase_two_launch_prep: float = 0.45
@export var phase_two_fakeout_wait: float = 3.0
@export var phase_two_rise_duration: float = 1.15
@export_range(0.1, 1.0, 0.05) var phase_two_slowmo_scale: float = 0.5
@export var death_revert_duration: float = 1.85
@export_range(0.1, 1.0, 0.05) var true_death_time_scale: float = 0.5
@export var crimson_return_wait_max: float = 4.5
@export_range(0.0, 0.5, 0.05) var crimson_return_done_ratio: float = 0.15

@export_group("Phase Two Sky Dive")
@export_range(1, 10, 1) var sky_dive_count: int = 5
@export var sky_dive_air_delay: float = 1.0
@export var sky_dive_warn_time: float = 0.70
@export var sky_dive_final_warn_time: float = 1.0
@export var sky_dive_track_time: float = 0.40
@export var sky_dive_track_speed: float = 5.5
@export var sky_dive_radius: float = 3.0
@export var sky_dive_damage: int = 2
@export var sky_dive_final_radius: float = 5.2
@export var sky_dive_final_damage: int = 3
@export_range(4, 48, 1) var sky_dive_final_gold_count: int = 28
@export var sky_dive_impact_frame_duration: float = 0.36
@export var sky_dive_impact_hitstop: float = 0.13
@export var sky_launch_wind_radius: float = 5.0
@export var sky_launch_push_speed: float = 15.0
@export var sky_dive_height: float = 16.0
@export var sky_dive_drop_time: float = 0.16
@export var sky_dive_land_hold: float = 0.22
@export var sky_dive_final_hold: float = 0.78

@export_group("Phase Two Resonance Slam")
@export var resonance_duration: float = 1.65
@export var resonance_lift_hold: float = 0.50
@export var resonance_push_radius: float = 42.0
@export var resonance_push_speed: float = 19.0
@export var resonance_wave_speed: float = 11.0
@export var resonance_feather_warn: float = 0.25
@export var resonance_post_hold: float = 0.45

@export_group("Phase Two Crimson & Rift")
@export var crimson_speed_mult: float = 1.6
@export_range(8, 60, 1) var p2_radial_count: int = 30
@export var p2_wall_refire_speed_ratio: float = 0.85
@export var crimson_flight_lifetime: float = 5.2
@export var p2_barrage_duration: float = 5.0
@export var p2_barrage_relaunch_interval: float = 0.065
@export var p2_barrage_lift_height: float = 1.55
@export var p2_barrage_lift_time: float = 0.34
@export var p2_gold_count_mult: float = 1.3
@export var p2_gold_chase_mult: float = 1.3
@export var vertical_slash_range: float = 68.0
@export var vertical_slash_height: float = 4.6
@export var vertical_slash_damage: int = 2
@export var portal_size: Vector2 = Vector2(2.3, 3.1)
@export var portal_open_time: float = 0.28
@export var chain_max_range: float = 68.0
@export var chain_bind_duration: float = 2.0
@export var chain_fade_time: float = 0.55

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
@export var arc_width: float = 15.2
@export var arc_range: float = 25.5
@export_range(1, 16, 1) var arc_gold_count: int = 8

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
