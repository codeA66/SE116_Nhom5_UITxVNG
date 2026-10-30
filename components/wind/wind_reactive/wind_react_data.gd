class_name WindReactData
extends Resource
## Cấu hình phản ứng hình ảnh, tách khỏi lực gameplay.

@export_group("Gust")
@export_range(0.01, 20.0) var recovery_seconds: float = 1.4
@export_range(0.01, 50.0) var full_strength: float = 10.0
@export_range(0.0, 2.0) var bend_amount: float = 0.7
@export_range(0.0, 30.0) var flutter_speed: float = 8.0
@export_range(0.0, 30.0) var windmill_boost: float = 12.0
@export_range(0.0, 30.0) var windmill_decay: float = 2.0
@export_range(0, 8) var loose_particle_count: int = 6
