class_name FireCycloneData
extends ForgeSkillData
## Lốc Lửa (Gió + Lửa, phím R): phóng một cột lốc đang cháy đi chậm về phía trước, hút quái nhỏ vào và đốt
## mọi thứ cháy được trên đường. Dùng lại hố hút gió (WindVortex) + lốc lửa (FireVortex) có sẵn.

const ID := &"fire_cyclone"

@export var cyclone_scene: PackedScene = preload("res://abilities/forge/fire_cyclone/fire_cyclone.tscn")
## Số lốc tạo sẵn trong pool
@export_range(1, 8) var pool_size: int = 2

@export_group("Cast")
## Mốc (s) lốc xuất hiện tính từ lúc bấm
@export_range(0.0, 2.0, 0.01) var cast_time: float = 0.3
## Tổng thời gian đứng ra chiêu
@export_range(0.05, 3.0, 0.01) var duration: float = 0.55
@export_range(0.0, 30.0, 0.1) var cooldown: float = 3.0
@export var animation: StringName = &"Attack_Melee"
@export var anim_speed: float = 1.0

@export_group("Cyclone")
## Lốc xuất hiện cách player bấy nhiêu mét theo hướng ra chiêu
@export_range(0.0, 6.0, 0.1) var spawn_distance: float = 1.5
## Tốc độ lốc trôi (m/s)
@export_range(0.0, 20.0, 0.1) var speed: float = 2.0
## Lốc sống bao lâu (s)
@export_range(0.1, 20.0, 0.1) var lifetime: float = 3.0


func get_lockout() -> float:
	return duration + cooldown
