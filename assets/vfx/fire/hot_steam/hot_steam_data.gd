class_name HotSteamData
extends Resource
## Hai lớp hơi được tạo sẵn, dùng lại theo nhịp của miệng phun.

@export_group("Đá magma")
@export var rock_size: Vector3 = Vector3(1.35, 1.9, 1.3)
@export_range(0.0, 1.0, 0.01) var resting_glow: float = 0.12
@export_range(0.0, 1.0, 0.01) var warning_glow: float = 0.55
@export_group("Hơi nước")
@export_range(1, 96, 1) var jet_particles: int = 40
@export_range(1, 32, 1) var warning_particles: int = 8
@export_range(0.1, 3.0, 0.05) var lifetime: float = 0.8
@export_range(0.05, 3.0, 0.05) var cloud_size: float = 0.85
@export_range(0.0, 45.0, 1.0) var spread_degrees: float = 12.0
@export_range(0.0, 5.0, 0.1) var buoyancy: float = 1.2
@export_range(0.0, 2.0, 0.05) var jet_lift: float = 0.1
@export_range(0.05, 2.0, 0.05) var warning_speed: float = 0.7
