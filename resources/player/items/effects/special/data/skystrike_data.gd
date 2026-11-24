class_name SkystrikeData
extends Resource

@export_group("Nạp")
@export_range(1, 50, 1, "or_greater") var hits_to_fill: int = 12

@export_group("Bay và đáp")
@export_range(0.5, 5.0, 0.05) var lift_height: float = 2.65
@export_range(0.0, 0.4, 0.01) var anticipation: float = 0.10
@export_range(0.08, 1.0, 0.01) var rise_time: float = 0.44
@export_range(0.08, 1.0, 0.01) var descent_time: float = 0.42
@export_range(0.1, 10.0, 0.05, "or_greater") var aim_time: float = 3.0

@export_group("Vụ nổ")
@export_range(0, 30, 1, "or_greater") var damage: int = 4
@export_range(0.1, 12.0, 0.1, "or_greater", "suffix:m") var radius: float = 4.0
@export_range(0.0, 1.0, 0.01) var flight_time: float = 0.18
@export_range(0.0, 2.0, 0.1) var floor_probe_above: float = 1.3
@export_range(0.1, 4.0, 0.1) var floor_probe_below: float = 1.5
