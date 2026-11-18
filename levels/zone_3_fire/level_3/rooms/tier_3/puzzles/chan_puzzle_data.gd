class_name ChanPuzzleData
extends Resource
## Nhịp rèn và thời gian thao tác cho phòng Chấn.

@export_group("Nhịp búa")
@export_range(0.1, 30.0, 0.05, "or_greater") var cycle_time: float = 5.0
@export_range(0.05, 10.0, 0.05, "or_greater") var warning_time: float = 1.0
@export_range(0.05, 5.0, 0.05, "or_greater") var wave_time: float = 0.55
@export_range(0.05, 15.0, 0.05, "or_greater") var power_time: float = 3.0
@export_range(1, 10) var wave_damage: int = 1

@export_group("Giao chiến toàn phòng")
@export_range(0.1, 30.0, 0.05, "or_greater") var combat_cycle_time: float = 2.25
@export_range(0.05, 10.0, 0.05, "or_greater") var combat_warning_time: float = 0.65

@export_group("Khối đồng")
@export_range(0.05, 3.0, 0.05, "or_greater") var slide_time: float = 0.28
