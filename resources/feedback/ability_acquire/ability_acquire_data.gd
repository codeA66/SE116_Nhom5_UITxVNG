class_name AbilityAcquireData
extends Resource
## Tham số trình diễn dùng chung; đổi nguyên tố bằng AbilityData, không đổi logic.
@export_group("Phases")
@export var lift_time: float = 0.8
@export var gather_time: float = 2.1
@export var breath_time: float = 0.10
@export var burst_time: float = 0.50
@export var settle_time: float = 1.05
@export var panel_time: float = 0.45
@export var fly_time: float = 0.65
@export var slot_time: float = 0.30
@export var title_time: float = 0.5
@export var minimum_time: float = 0.001
@export var freeze_world: bool = true
@export var confirm_action: StringName = &"ui_accept"
@export var phase_order: PackedStringArray = PackedStringArray(["Lift","Gather","Burst","Settle","Reveal"])
@export_group("Actor and book")
@export var lift_height: float = 0.60
@export var face_camera: bool = true
@export var facing_time: float = 0.24
@export var book_rise: float = 0.45
@export var focus_height: float = 0.85
@export var book_grain: float = 25.0
@export var book_edge: float = 0.075
@export var book_fallback: Color = Color("#9b8871")
@export_group("Particles")
@export_range(0, 96) var mote_count: int = 72
@export_range(0, 12) var foreground_count: int = 6
@export_range(0, 96) var spark_count: int = 24
@export_range(0, 96) var dust_count: int = 8
@export_range(1, 96) var pool_capacity: int = 96
@export var particle_seed: int = 1701
@export var gather_radius: float = 5.8
@export var gather_height: float = 2.4
@export var gather_spin: float = 2.2
@export var gather_acceleration: float = 2.3
@export_range(0.0, 0.9) var gather_stagger: float = 0.48
@export var mote_stretch: float = 4.2
@export var mote_size: float = 0.14
@export var foreground_size: float = 0.55
@export var foreground_depth: float = 8.0
@export var foreground_spread: float = 2.2
@export var spark_radius: float = 4.0
@export var dust_radius: float = 0.55
@export_range(0.1, 0.95) var landing_start: float = 0.78
@export var dust_size: float = 0.14
@export var dust_height: float = 0.06
@export_group("Light shapes")
@export_range(1, 12) var ray_count: int = 8
@export_range(4, 32) var ray_segments: int = 16
@export var ray_length: float = 5.2
@export var ray_width: float = 0.48
@export var ray_length_variation: float = 0.28
@export var ray_curl: float = 0.14
@export var core_size: float = 4.4
@export var charge_core_ratio: float = 0.48
@export var charge_power: float = 2.0
@export var stream_width: float = 0.22
@export var stream_radius: float = 1.0
@export var stream_height: float = 3.5
@export_range(1, 12) var stream_count: int = 3
@export var ring_radius: float = 5.2
@export var ring_width: float = 0.065
@export var ring_floor: float = 0.035
@export var fallback_accent: Color = Color("#a6e0ef")
@export var hot_color: Color = Color("#f2fcff")
@export var burst_intensity: float = 1.0
@export var maximum_intensity: float = 2.0
@export_group("Screen")
@export var gather_dim: float = 0.28
@export var gather_desaturation: float = 0.42
@export var reveal_dim: float = 0.94
@export var fullscreen_pulse: float = 0.28
@export var gather_pulse: float = 0.065
@export var exposure_gain: float = 1.0
@export var local_radiance: float = 0.42
@export var focus_radius: float = 0.22
@export_group("Feedback")
@export var shake: float = 0.30
@export var hitstop: float = 0.045
@export_group("UI")
@export var canvas_layer: int = 20
@export var panel_size: Vector2 = Vector2(680, 520)
@export var illustration_size: float = 160.0
@export var fly_icon_size: float = 48.0
@export var caption_font: int = 15
@export var title_font: int = 40
@export var body_font: int = 20
@export var hint_font: int = 16
@export var panel_motes: int = 8
@export var panel_mote_radius: float = 110.0
@export var panel_mote_size: float = 1.8
@export var panel_mote_speed: float = 0.35
@export var pulse_radius: float = 42.0
@export var caption: String = "KỸ NĂNG ĐÃ THỨC TỈNH"
@export var continue_caption: String = "Xác nhận để tiếp tục"
@export var control_caption: String = "Nhấn %s để sử dụng"
@export_group("Audio hooks")
@export var audio_descend: AudioStream
@export var audio_gather: AudioStream
@export var audio_burst: AudioStream
@export var audio_panel: AudioStream
@export var audio_icon_land: AudioStream
