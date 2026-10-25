class_name SkyFerryData
extends Resource
## Thông số thuyền bay chở khách (gọi ở trụ, tự cất cánh khi có người đứng trên boong).

@export_group("Flight")
## Tốc độ bay tới bến khi được gọi (m/s)
@export var approach_speed: float = 6.0
## Tốc độ chở khách tới bến mới (m/s)
@export var travel_speed: float = 5.0
@export var acceleration: float = 3.0
## Còn bấy nhiêu mét tới cuối đường bay thì giảm tốc để cập bến êm
@export var slow_distance: float = 4.0
## Tốc độ nhỏ nhất khi đang cập bến: không đứng khựng trước bến
@export var min_speed: float = 0.6
## Độ nhanh mũi thuyền xoay theo hướng đường bay. Nhỏ = xoay êm (đỡ chao ở chỗ cong), lớn = bám sát đường
@export var turn_response: float = 2.5

@export_group("Boarding")
## Người chơi đứng trên boong (chạm sàn) đủ bấy nhiêu giây thì thuyền cất cánh
@export var board_delay: float = 1.5

@export_group("Hover")
## Nhấp nhô lên xuống khi đậu (m)
@export var bob_amplitude: float = 0.05
@export var bob_speed: float = 1.6
