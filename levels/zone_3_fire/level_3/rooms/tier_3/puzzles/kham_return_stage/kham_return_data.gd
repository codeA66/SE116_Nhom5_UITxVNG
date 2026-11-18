class_name KhamReturnData
extends Resource
## Cấu hình riêng cho lượt quay về; không ảnh hưởng nhịp phase 1.

@export var thermal: KhamPuzzleData
@export var sinking: KhamSinkData = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/kham_sinking_route/kham_sink_data.tres")
@export_group("Thời gian làm nguội")
@export_range(0.1, 60.0, 0.1) var default_cold_time: float = 9.0
@export var cold_times: Dictionary[StringName, float] = {&"D": 9.0, &"E": 9.0, &"F": 9.0, &"G": 10.0}
