class_name WrathVfxStyle
extends Resource
## Giữ kích thước và màu riêng để bùa không phụ thuộc shader của nguyên tố Lửa.

@export_group("Hình dáng")
@export_range(0.0, 3.0, 0.01, "or_greater") var radius: float = 0.78
@export var center_height: float = 0.62
@export_range(0.0, 3.0, 0.01, "or_greater") var rise: float = 1.35
@export_range(0.0, 0.5, 0.01, "or_greater") var stroke_width: float = 0.42
@export_range(0.05, 0.5, 0.01) var arc_span: float = 0.36

@export_group("Màu")
@export var ink_color: Color = Color("781e31")
@export var edge_color: Color = Color("fff0d4")
@export var accent_color: Color = Color("ef5544")
@export_range(0.0, 1.0, 0.01) var opacity: float = 0.90

@export_group("Nhịp")
@export_range(0.0, 3.0, 0.01, "or_greater") var spin_speed: float = 0.55
@export_range(0.0, 1.0, 0.01, "or_greater") var spawn_time: float = 0.14
@export_range(0.0, 1.0, 0.01, "or_greater") var fade_time: float = 0.20
@export_range(0.0, 1.0, 0.01) var refresh_strength: float = 0.35
@export_range(0.0, 1.0, 0.01, "or_greater") var pulse_time: float = 0.24
@export_range(0.0, 4.0, 0.01, "or_greater") var pulse_radius_ratio: float = 1.8
@export_range(0.0, 1.0, 0.01) var pressure_opacity: float = 0.35

@export_group("Hạt")
@export_range(0, 24) var particle_count: int = 12
@export_range(0.0, 2.0, 0.01, "or_greater") var particle_lifetime: float = 0.42
@export_range(0.0, 2.0, 0.01, "or_greater") var particle_speed: float = 1.0
@export_range(0.0, 0.4, 0.005, "or_greater") var particle_size: float = 0.055

@export_group("Hạt kích hoạt")
@export_range(0, 12) var burst_count: int = 10
@export_range(0.0, 2.0, 0.01, "or_greater") var burst_lifetime: float = 0.28
@export_range(0.0, 8.0, 0.01, "or_greater") var burst_speed: float = 3.4
@export_range(0.0, 0.4, 0.005, "or_greater") var burst_size: float = 0.09

@export_group("Khói mực")
@export_range(0, 8) var wisp_count: int = 8
@export_range(0.0, 2.0, 0.01, "or_greater") var wisp_lifetime: float = 0.55
@export_range(0.0, 2.0, 0.01, "or_greater") var wisp_speed: float = 0.9
@export_range(0.0, 1.0, 0.01, "or_greater") var wisp_size: float = 0.28
