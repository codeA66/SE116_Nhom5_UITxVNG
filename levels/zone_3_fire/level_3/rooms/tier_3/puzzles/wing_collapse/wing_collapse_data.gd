class_name WingCollapseData
extends Resource
## Thông số nhịp rung, sập và rung camera khi một khu vực ở Tier 3 rơi xuống dung nham.

@export_group("Rung trước khi sập")
## Thời gian rung lắc tại chỗ trước khi các mảnh bắt đầu rơi (giây)
@export_range(0.0, 5.0, 0.05) var rumble_duration: float = 0.85
## Biên độ rung lắc của từng mảnh trước khi rơi (mét)
@export_range(0.0, 1.0, 0.01) var rumble_amplitude: float = 0.18
## Tần số rung lắc tại chỗ
@export_range(1.0, 60.0, 1.0) var rumble_frequency: float = 28.0

@export_group("Rơi lệch nhịp")
## Độ trễ lệch nhịp giữa hai mảnh liên tiếp tính từ mép Hub ra ngoài (giây)
@export_range(0.0, 2.0, 0.01) var stagger_step: float = 0.045
## Tổng độ trễ tối đa cho toàn bộ khu vực để phòng lớn không kéo dài quá lâu (giây)
@export_range(0.0, 5.0, 0.05) var max_stagger_span: float = 1.05
## Gia tốc rơi xuống dung nham (m/s²)
@export_range(1.0, 200.0, 0.5) var fall_gravity: float = 34.0
## Góc nghiêng tối đa khi mảnh rơi xuống (độ)
@export_range(0.0, 90.0, 1.0) var max_tilt_degrees: float = 28.0
## Độ cao Y mục tiêu dưới mặt biển dung nham để ẩn mảnh
@export var sink_y: float = -16.0
## Giới hạn thời gian sập tối đa sau khi hết pha rung tại chỗ (giây)
@export_range(0.1, 15.0, 0.1) var max_collapse_duration: float = 2.6

@export_group("Camera shake")
## Lực trauma ban đầu khi bắt đầu sập (0..1)
@export_range(0.0, 1.0, 0.05) var initial_trauma: float = 0.95
## Lực trauma bồi thêm định kỳ trong lúc sập (0..1)
@export_range(0.0, 1.0, 0.05) var pulse_trauma: float = 0.72
## Chu kỳ bồi thêm camera shake trong lúc sập (giây)
@export_range(0.05, 2.0, 0.05) var pulse_interval: float = 0.28
## Khoảng dừng ngắn sau khi rơi xong trước khi trả camera về player (giây)
@export_range(0.0, 2.0, 0.05) var post_fall_hold: float = 0.35
