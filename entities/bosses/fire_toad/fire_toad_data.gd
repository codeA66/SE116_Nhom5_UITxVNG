class_name FireToadData
extends Resource
## Thông số Ếch Hoả Vương (boss cuối map Lửa): máu, các mốc phase và hai bộ skill (bình thường / cuồng loạn).

@export var max_health: int = 40

@export_group("Skill")
@export var normal: FireToadSkills
## Bộ skill khi cuồng loạn (máu <= enrage_ratio)
@export var enraged: FireToadSkills

@export_group("Phase 2: bay lên")
## Máu còn <= tỉ lệ này thì bay lên (một lần)
@export_range(0.0, 1.0, 0.01) var hover_ratio: float = 0.5
## Bay bao lâu rồi đáp xuống (s)
@export_range(1.0, 60.0, 0.5) var hover_duration: float = 12.0
## Bay cao hơn sàn bấy nhiêu mét
@export_range(1.0, 30.0, 0.5) var hover_height: float = 6.0
## Thời gian bay lên / hạ xuống (s)
@export_range(0.1, 5.0, 0.05) var hover_rise_time: float = 1.2
## Lúc bay: mỗi chừng này giây thả một quả cầu lửa rơi
@export_range(0.05, 5.0, 0.05) var hover_drop_interval: float = 0.45

@export_group("Cuồng loạn")
## Máu còn <= tỉ lệ này thì cuồng loạn (dùng bộ skill enraged)
@export_range(0.0, 1.0, 0.01) var enrage_ratio: float = 0.2
## Màu phủ thân khi cuồng loạn
@export var enrage_tint: Color = Color(1.0, 0.25, 0.1, 0.35)

@export_group("Nhảy")
## Đỉnh vòng cung khi nhảy ra / vào sân, đổi bệ (m)
@export_range(0.5, 20.0, 0.1) var leap_height: float = 5.0
## Thời gian một lần nhảy ra / vào sân (s)
@export_range(0.1, 5.0, 0.05) var leap_time: float = 0.9

@export_group("Bắn thẳng")
## Cầu lửa bắn từ bệ ngoài bay ngang ở độ cao này so với mặt sàn đấu (m). Bay ngang để quả lệch không cắm xuống sàn
## giữa đường; phải cao hơn mặt bệ ngoài + bán kính đạn và thấp hơn đỉnh hurtbox player + bán kính đạn
@export_range(0.3, 3.0, 0.05) var shot_height: float = 1.5

@export_group("Trúng đòn")
@export var hit_flash_color: Color = Color(1.0, 0.85, 0.7, 0.7)
@export_range(0.02, 1.0, 0.01) var hit_flash_time: float = 0.1
