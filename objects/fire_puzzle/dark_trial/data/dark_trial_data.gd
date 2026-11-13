class_name DarkTrialData
extends Resource
## Thông số thử thách u tối: thời gian, các trụ, vùng tối, cờ hoàn thành. Chỉnh trong .tres, không sửa code.

## Thời gian cho cả thử thách (s)
@export_range(5.0, 900.0, 1.0) var duration: float = 120.0
## Còn dưới mức này thì đồng hồ đỏ và nháy (s)
@export_range(0.0, 120.0, 1.0) var warning_time: float = 20.0
## Đồng hồ chạy theo giờ thật: hitstop (Engine.time_scale) không làm đồng hồ khựng lúc đánh trúng
@export var real_time_clock: bool = true
@export var pillars: Array[DarkTrialPillarData] = []
## Các hộp phủ vùng tối trong lúc thử thách (AABB tọa độ thế giới)
@export var dark_boxes: Array[AABB] = []
@export_range(0.0, 1.0, 0.01) var dark_ambient_ratio: float = 0.05
## Cờ lưu khi thắng
@export var done_flag: StringName
@export var start_prompt: String = "BẮT ĐẦU THỬ THÁCH"
@export var retry_prompt: String = "THỬ LẠI"
