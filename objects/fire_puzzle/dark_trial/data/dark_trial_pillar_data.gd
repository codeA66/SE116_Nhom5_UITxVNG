class_name DarkTrialPillarData
extends Resource
## Một trụ năng lượng của thử thách u tối: chỗ đặt, loại quái lồng sinh ra, nhịp sinh.

## Tên node trụ (để test và bản đồ dễ đọc)
@export var name: StringName = &"Pillar"
## Vị trí chân trụ (tọa độ thế giới, mặt sàn đi lại)
@export var position: Vector3
@export var enemy_scene: PackedScene
@export_range(0.1, 60.0, 0.1) var spawn_interval: float = 4.0
@export_range(1, 20) var max_alive: int = 3
## Vùng player phải đứng trong để lồng sinh quái (thường phủ cả phòng), tâm đáy lệch active_area_offset so với trụ
@export var active_area_size: Vector3 = Vector3(20.0, 4.0, 20.0)
@export var active_area_offset: Vector3 = Vector3.ZERO
