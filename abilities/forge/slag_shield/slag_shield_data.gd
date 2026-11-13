class_name SlagShieldData
extends ForgeSkillData
## Khiên xỉ (giữ phím V): dựng tấm xỉ trước mặt, chặn đòn cận chiến và đạn tới trong cung phía trước, dội ngược
## đạn dội được (cầu lửa của Quỷ Xương Lửa). Giữ khiên thì đi chậm, không đánh; tốn năng lượng theo thời gian.

const ID := &"slag_shield"

@export var shield_scene: PackedScene = preload("res://abilities/forge/slag_shield/slag_shield.tscn")

@export_group("Guard")
## Độ rộng cung chặn phía trước (độ). 0 = không chặn gì, 360 = chặn mọi hướng
@export_range(0.0, 360.0, 1.0) var arc_degrees: float = 120.0
## Dội ngược đạn dội được thay vì chỉ chặn
@export var reflects_projectiles: bool = true

@export_group("Hold")
## Giữ ít nhất bấy nhiêu giây dù đã nhả phím (bấm nhanh vẫn thấy khiên)
@export_range(0.0, 2.0, 0.01) var min_hold: float = 0.2
## Cứ bấy nhiêu giây giữ khiên thì tốn thêm 1 năng lượng; hết năng lượng thì hạ khiên
@export_range(0.05, 30.0, 0.05) var drain_interval: float = 1.0
## Tốc độ đi khi giữ khiên so với chạy thường
@export_range(0.0, 1.0, 0.01) var move_scale: float = 0.35
@export_range(0.0, 30.0, 0.1) var cooldown: float = 0.4
@export var animation: StringName = &"Idle_Sword"


## Khoá tính từ lúc bấm: chỉ phần hồi chiêu; thời gian giữ do người chơi quyết định
func get_lockout() -> float:
	return min_hold + cooldown
