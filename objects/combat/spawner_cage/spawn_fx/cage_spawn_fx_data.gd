class_name CageSpawnFxData
extends Resource
## Thông số hiệu ứng lồng sinh quái (CageSpawnFx). Chỉnh trong file .tres, không cần sửa code.

@export_group("Tia lửa bay")
## Thời gian tia lửa bay từ lồng tới chỗ quái (s)
@export_range(0.05, 3.0, 0.01) var travel_time: float = 0.35
## Độ cao đỉnh vòng cung so với đường thẳng lồng → chỗ quái (m)
@export_range(0.0, 10.0, 0.1) var arc_height: float = 2.2
## Tia lửa bắt đầu ở độ cao này so với chân lồng (m)
@export_range(0.0, 6.0, 0.1) var launch_height: float = 1.6

@export_group("Bùng khi chạm đất")
## Cỡ vòng sóng lan trên sàn lúc kết thúc (m)
@export_range(0.5, 12.0, 0.1) var ring_scale: float = 3.2
@export_range(0.05, 3.0, 0.01) var ring_time: float = 0.45
@export_range(0.0, 20.0, 0.1) var flash_energy: float = 4.0
## Đèn ở lồng chớp lúc phóng tia
@export_range(0.0, 20.0, 0.1) var cage_flash_energy: float = 3.0
@export_range(0.0, 1.0, 0.01) var land_trauma: float = 0.05
