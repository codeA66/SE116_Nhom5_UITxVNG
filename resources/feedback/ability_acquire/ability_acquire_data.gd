class_name AbilityAcquireData
extends Resource
## Tham số trình diễn dùng chung; đổi nguyên tố bằng AbilityData, không đổi logic.
@export_group("Phases")
@export var lift_time: float = 1.1
@export var gather_time: float = 2.8
@export var breath_time: float = 0.08
@export var burst_time: float = 0.32
@export var settle_time: float = 1.10
@export var panel_time: float = 0.75
@export var fly_time: float = 0.65
@export var slot_time: float = 0.30
@export var title_time: float = 0.85
@export var minimum_time: float = 0.001
@export var freeze_world: bool = true
@export var confirm_action: StringName = &"ui_accept"
@export var phase_order: PackedStringArray = PackedStringArray(["Lift","Gather","Burst","Settle","Reveal"])
@export_group("Actor and book")
@export var visual_path: NodePath = ^"Model/Visual"
@export var fallback_visual_path: NodePath = ^"Model"
@export var lift_height: float = 0.90
@export var face_camera: bool = true
@export var facing_time: float = 0.24
@export_range(0.0, 0.65) var camera_push: float = 0.38
@export var float_amplitude: float = 0.025
@export var float_speed: float = 2.8
@export var book_rise: float = 0.25
@export var book_fade: Vector2 = Vector2(0.15,0.90)
@export var book_edge_strength: float = 0.12
@export_range(0, 16) var book_mote_count: int = 8
@export var book_mote_size: float = 0.045
@export var focus_height: float = 0.65
@export var book_grain: float = 25.0
@export var book_edge: float = 0.075
@export var book_fallback: Color = Color("#9b8871")
@export_group("Ceremony pose")
@export var pose_enabled: bool = true
@export_range(0.0, 1.0) var pose_strength: float = 1.0
@export var landing_squash: float = 0.10
@export var hidden_visual_names: PackedStringArray = PackedStringArray(["Sword","BowHold"])
@export var pose_children: Dictionary[StringName, StringName] = {
	&"upper_arm.L": &"forearm.L", &"forearm.L": &"hand.L",
	&"upper_arm.R": &"forearm.R", &"forearm.R": &"hand.R",
	&"thigh.L": &"shin.L", &"shin.L": &"foot.L",
	&"thigh.R": &"shin.R", &"shin.R": &"foot.R",
}
@export var pose_directions: Dictionary[StringName, Vector3] = {
	&"upper_arm.L": Vector3(0.85,0.35,0.05), &"forearm.L": Vector3(0.45,0.80,0.15),
	&"upper_arm.R": Vector3(-0.85,0.35,0.05), &"forearm.R": Vector3(-0.45,0.80,0.15),
	&"thigh.L": Vector3(0.10,-0.95,0.22), &"shin.L": Vector3(0.03,-0.95,-0.15),
	&"thigh.R": Vector3(-0.10,-0.95,0.22), &"shin.R": Vector3(-0.03,-0.95,-0.15),
}
@export_group("Particles")
@export_range(0, 96) var mote_count: int = 84
@export_range(0, 12) var foreground_count: int = 6
@export_range(0, 96) var spark_count: int = 32
@export_range(0, 64) var linger_count: int = 24
@export_range(0, 96) var dust_count: int = 8
@export_range(1, 96) var pool_capacity: int = 96
@export var particle_seed: int = 1701
@export var gather_radius: float = 6.2
@export var gather_height: float = 4.2
@export var gather_spin: float = 2.2
@export var gather_acceleration: float = 2.0
@export_range(0.0, 1.0) var gather_stagger: float = 1.0
@export_range(1, 8) var gather_waves: int = 4
@export var gather_flight_time: Vector2 = Vector2(0.60,0.90)
@export var gather_launch_jitter: float = 0.16
@export_range(0.5, 2.0) var gather_wave_overlap: float = 1.6
@export var randomize_gather: bool = true
@export var mote_stretch: float = 5.0
@export_range(0.0, 1.0) var streak_ratio: float = 0.18
@export var mote_size: float = 0.08
@export var foreground_size: float = 0.45
@export var foreground_depth: float = 6.0
@export var foreground_spread: float = 1.8
@export var spark_radius: float = 4.0
@export var dust_radius: float = 0.55
@export_range(0.1, 0.95) var landing_start: float = 0.78
@export var dust_size: float = 0.14
@export var dust_height: float = 0.06
@export_group("Light shapes")
@export_range(1, 24) var ray_count: int = 12
@export_range(4, 32) var ray_segments: int = 16
@export var ray_length: float = 7.2
@export var ray_width: float = 0.22
@export var burst_expand_time: float = 0.055
@export var burst_flash_time: float = 0.065
@export var ray_decay: float = 2.2
@export var ray_length_variation: float = 0.60
@export var ray_curl: float = 0.025
@export var ray_angle_jitter: float = 1.0
@export var core_size: float = 4.0
@export var charge_core_ratio: float = 0.25
@export var charge_core_opacity: float = 0.12
@export var core_decay: float = 4.0
@export var charge_power: float = 2.0
@export var stream_width: float = 0.055
@export var stream_radius: float = 0.42
@export var stream_height: float = 3.2
@export_range(0.0, 0.98) var stream_compression: float = 0.70
@export_range(1, 24) var stream_count: int = 2
@export var ring_radius: float = 5.2
@export var ring_width: float = 0.012
@export_range(0.0, 1.0) var ring_opacity: float = 0.20
@export var ring_floor: float = 0.035
@export var fallback_accent: Color = Color("#a6e0ef")
@export var hot_color: Color = Color("#f2fcff")
@export var burst_intensity: float = 1.0
@export var maximum_intensity: float = 2.0
@export_group("Screen")
@export var gather_dim: float = 0.62
@export var gather_desaturation: float = 0.65
@export var reveal_dim: float = 0.94
@export var fullscreen_pulse: float = 0.28
@export var gather_pulse: float = 0.025
@export var exposure_gain: float = 0.12
@export var local_radiance: float = 0.18
@export var shock_gain: float = 0.004
@export var shock_width: float = 0.04
@export var focus_radius: float = 0.27
@export_group("Feedback")
@export var shake: float = 0.34
@export var hitstop: float = 0.055
@export_group("UI")
@export var canvas_layer: int = 20
@export var confirm_mouse_button: MouseButton = MOUSE_BUTTON_LEFT
@export var panel_size: Vector2 = Vector2(800, 560)
@export var illustration_size: float = 260.0
@export var fly_icon_size: float = 48.0
@export var caption_font: int = 15
@export var title_font: int = 42
@export var title_typeface: Font
@export var body_font: int = 20
@export var hint_font: int = 16
@export var panel_motes: int = 8
@export var panel_mote_radius: float = 155.0
@export var panel_mote_size: float = 1.8
@export var panel_mote_speed: float = 0.35
@export var pulse_radius: float = 42.0
@export var caption_y: float = 0.45
@export var title_y: float = 0.51
@export var divider_y: float = 0.65
@export var hint_y: float = 0.70
@export var description_y: float = 0.79
@export var continue_y: float = 0.96
@export var caption: String = "KỸ NĂNG ĐÃ THỨC TỈNH"
@export var continue_caption: String = "Chuột trái / Enter để tiếp tục"
@export var control_caption: String = "Nhấn %s để sử dụng"
@export_group("Audio hooks")
@export var audio_descend: AudioStream
@export var audio_gather: AudioStream
@export var audio_burst: AudioStream
@export var audio_panel: AudioStream
@export var audio_icon_land: AudioStream
