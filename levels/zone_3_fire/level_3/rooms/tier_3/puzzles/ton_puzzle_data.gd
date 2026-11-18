class_name TonPuzzleData
extends Resource
## Nhịp và ngưỡng của một lượt mang lửa.

@export_group("Wind")
@export_range(0.1, 15.0, 0.1) var calm_time: float = 1.8
@export_range(0.1, 15.0, 0.1) var gust_time: float = 4.2
@export_range(0.0, 3.0, 0.05) var gust_warning: float = 0.45
@export_group("Flame")
@export_range(0.05, 15.0, 0.05) var exposure_limit: float = 1.6
@export_range(0.0, 1.0, 0.05) var warning_ratio: float = 0.45
@export_range(0.01, 8.0, 0.05) var exposure_recovery: float = 0.65
@export_range(0.0, 10.0, 0.05) var non_fire_exposure: float = 0.55
@export var fire_element: StringName = &"fire"
@export var fire_skills: Array[StringName] = [&"flame_breath", &"fire_cyclone", &"slag_shield"]
