class_name LaserTiming
extends Resource
## Nhịp bật / tắt của tượng bắn laser. Nhiều tượng dùng chung một nhịp, lệch pha bằng phase_offset trên từng tượng.

## Thời gian tia bật (gây sát thương), giây
@export_range(0.05, 30.0, 0.05) var on_time: float = 1.5
## Thời gian tia tắt hẳn (an toàn), giây; tính cả thời gian báo trước ở cuối
@export_range(0.0, 30.0, 0.05) var off_time: float = 1.5
## Phần cuối của off_time hiện tia báo trước (mờ, nhấp nháy, không gây sát thương)
@export_range(0.0, 5.0, 0.05) var warn_time: float = 0.5
## Tầm bắn tối đa khi không có tường chặn, mét
@export_range(1.0, 200.0, 0.5) var max_range: float = 30.0


func cycle_length() -> float:
	return on_time + off_time
