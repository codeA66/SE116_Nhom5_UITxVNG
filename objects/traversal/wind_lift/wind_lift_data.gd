class_name WindLiftData
extends Resource
## Thông số bệ nâng bằng gió. Chỉnh trong file .tres, không cần sửa code.

@export_group("Wind")
## Thời gian gió từ lặng lên mạnh hết cỡ khi trụ quạt vừa nạp đầy (s)
@export_range(0.05, 5.0, 0.05) var wind_ramp_up_time: float = 0.6
## Gió phải mạnh tới mức này (0..1) bệ mới bắt đầu nhấc lên
@export_range(0.0, 1.0, 0.05) var lift_threshold: float = 0.5
## Gió đổi theo số đèn còn sáng mượt trong bấy nhiêu giây (lúc đèn tắt dần)
@export_range(0.01, 2.0, 0.01) var wind_follow_time: float = 0.25
## Sức gió hiển thị khi mạnh nhất (chỉ là hình ảnh, không đẩy người chơi)
@export var visual_wind_strength: float = 6.0

@export_group("Rise")
@export var rise_max_speed: float = 2.2
@export var rise_acceleration: float = 3.0
## Bắt đầu giảm tốc khi còn cách điểm dừng trên bấy nhiêu mét, để cập êm
@export var rise_arrive_distance: float = 0.6

@export_group("Fall")
## Gió tắt hẳn thì bệ sụp xuống như rơi
@export var fall_gravity: float = 9.0
@export var fall_max_speed: float = 6.0
## Rung màn hình khi bệ đập xuống đáy (0 = không rung)
@export_range(0.0, 1.0) var landing_trauma: float = 0.25
