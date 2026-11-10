extends Resource
## Phạm vi riêng của quân trong phòng vua khỉ, không đổi stats của các phòng khác.
@export_range(1.0, 300.0, 1.0) var ground_detect_range: float = 110.0
@export_range(1.0, 300.0, 1.0) var ground_lose_range: float = 130.0
@export_range(1.0, 300.0, 1.0) var ground_leash_range: float = 130.0
@export_range(0.1, 3.0, 0.1) var roof_range_multiplier: float = 1.5
