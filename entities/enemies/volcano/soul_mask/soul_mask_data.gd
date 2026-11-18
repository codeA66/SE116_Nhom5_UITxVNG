class_name SoulMaskData
extends EnemyData
## Thông số Đầu Lửa: quái bay lượn vòng quanh player rồi há miệng tụ lực bắn tia.

@export var hover: HoverStats
@export var beam: SoulBeamData

@export_group("Orbit")
## Bán kính lượn vòng quanh player (m)
@export var orbit_radius: float = 6.0
## Lệch bán kính trong khoảng này thì chỉ bay ngang, không lại gần / lùi ra (m)
@export var orbit_tolerance: float = 1.0
## Tốc độ bay ngang so với max_speed
@export_range(0.0, 1.0) var orbit_speed_scale: float = 0.7
## Đổi chiều lượn sau khoảng ngẫu nhiên này (s)
@export var orbit_switch_min: float = 2.0
@export var orbit_switch_max: float = 4.0
