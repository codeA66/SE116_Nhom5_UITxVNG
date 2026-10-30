extends Resource
const COLOR_VARIANTS := [
	{"label": "Crimson · Original red", "hue": 0.0},
	{"label": "Amethyst · Purple", "hue": 0.77},
	{"label": "Glacier · Cyan", "hue": 0.50},
	{"label": "Venom · Green", "hue": 0.33},
	{"label": "Solar · Amber", "hue": 0.105},
	{"label": "Arcane · Blue", "hue": 0.63},
	{"label": "Pearl · White", "hue": 0.0, "saturation": 0.0},
]
## Artist controls in meters/seconds, analogous to the reference project's VFX styles.
@export_range(0.3, 3.0) var duration := 1.25
@export var cut_length := 4.6
@export var cut_width := 0.23
@export var cut_spacing := 0.57
@export var angle_degrees := 54.0
@export var seed_value := 71
@export var edge_color := Color(1.0, 0.003, 0.018, 1.0)
@export var hot_color := Color(1.0, 0.60, 0.52, 1.0)
@export_range(0.0, 1.0) var hue_shift := 0.0
@export_range(0.0, 1.0) var saturation_scale := 1.0
@export var intensity := 1.0
@export_range(0, 256) var smoke_count := 56
@export_range(0, 512) var ember_count := 160
@export_range(0, 64) var streak_count := 18
@export_range(0, 64) var ink_count := 28
