class_name DeathEffectData
extends Resource
## Thông số cảnh quái chết: dừng hình, rung, co model, màu vụ nổ. Mỗi loại quái đặt màu riêng trong một .tres.

@export_group("Impact")
## Dừng hình khi đòn kết liễu (s)
@export var kill_hitstop: float = 0.12
@export_range(0.0, 1.0) var trauma: float = 0.35

@export_group("Shrink")
## Model phồng lên rồi co về ~0: phồng tới tỉ lệ này
@export var grow_scale: float = 1.15
@export var grow_time: float = 0.07
@export var shrink_time: float = 0.2

@export_group("Burst")
@export var color: Color = Color(1.0, 0.5, 0.2)
@export var effect_scale: float = 1.0

@export_group("Puddle")
## Đường kính vũng máu dưới xác (m); 0 = không có
@export var puddle_size: float = 2.2
