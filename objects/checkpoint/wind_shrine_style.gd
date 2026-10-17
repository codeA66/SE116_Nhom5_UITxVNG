class_name WindShrineStyle
extends Resource
## Cùng một bảng màu cho pha lê, nét gió và ánh sáng trên bệ.

@export_group("Colors")
@export_range(0.1, 1.0) var stone_brightness: float = 0.5
@export var dormant_color: Color = Color("8b9596")
@export var active_color: Color = Color("f1f6f4")
@export var edge_color: Color = Color("d1edf2")
@export_range(0.0, 3.0) var emission_energy: float = 0.65
@export_range(0.0, 3.0) var edge_energy: float = 1.1
@export var stone_active_color: Color = Color("57b2c9")
@export_range(0.0, 1.0) var stone_tint_strength: float = 0.6
@export_range(0.0, 1.0) var stone_center_tint: float = 0.4

@export_group("Motion")
@export_range(0.0, 2.0) var activation_time: float = 0.45
@export_range(0.0, 0.15) var float_amplitude: float = 0.035
@export_range(0.0, 5.0) var float_speed: float = 1.4
@export_range(0.5, 3.0) var edge_width: float = 1.0

@export_group("Aura")
@export_range(0.0, 0.4) var aura_opacity: float = 0.085
@export_range(0.1, 2.0) var aura_size: float = 1.3
@export_range(0.0, 1.0) var ribbon_opacity: float = 0.45
@export_range(0.0, 1.0) var inlay_opacity: float = 0.18
