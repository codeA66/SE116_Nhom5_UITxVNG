class_name KhamPuzzleData
extends Resource
## Thông số của một lượt Khảm, tách khỏi tiến độ để mọi lần reset dùng cùng cấu hình.

@export var sinking: KhamSinkData = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/kham_sinking_route/kham_sink_data.tres")

@export_group("Đường đá")
@export_range(0.1, 60.0, 0.1) var first_cold_time: float = 6.0
@export_range(0.1, 60.0, 0.1) var west_cold_time: float = 8.0
@export_range(0.1, 60.0, 0.1) var north_cold_time: float = 8.0
@export_range(0.0, 10.0, 0.1) var heat_warning_time: float = 2.0
@export var hot_color: Color = Color(1.0, 0.22, 0.035)
@export var cold_color: Color = Color(0.4, 0.42, 0.44)
@export var warning_color: Color = Color(0.75, 0.28, 0.06)
@export_range(0.0, 4.0, 0.1) var magma_glow_strength: float = 1.2
@export_group("Van và cầu")
@export_range(0.05, 2.0, 0.05) var valve_turn_time: float = 0.35
@export_range(0.05, 5.0, 0.05) var bridge_open_time: float = 0.8
@export_range(0.1, 10.0, 0.1) var bridge_hidden_depth: float = 4.0
@export var valve_locked_color: Color = Color(0.45, 0.45, 0.47, 1.0)
@export_group("Chuyển phase")
@export_range(0.0, 5.0, 0.05) var phase_one_sink_time: float = 0.8
@export_range(0.1, 20.0, 0.1) var phase_one_sink_depth: float = 4.0
@export_group("Hơi phun")
@export_range(0.1, 20.0, 0.1) var vent_rest_time: float = 2.0
@export_range(0.1, 10.0, 0.1) var vent_warning_time: float = 0.8
@export_range(0.1, 10.0, 0.1) var vent_active_time: float = 1.0
@export_group("Phong ấn")
@export var seal_flag: StringName = &"level_3.t3_seal_kham"
@export var seal_id: StringName = &"kham"
