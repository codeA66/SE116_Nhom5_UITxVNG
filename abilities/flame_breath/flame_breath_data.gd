class_name FlameBreathData
extends SkillData
## Thông số kỹ năng Phun Lửa (phím Q): luồng lửa hình nón trước mặt, gây sát thương, KHÔNG đẩy (đẩy là việc của Gió).
## Chỉnh trong file .tres, không cần sửa code.

const ID := &"flame_breath"

## Đòn gây sát thương của luồng lửa (damage 1, knockback 0 theo luật game); mỗi lần phun một mục tiêu chỉ trúng 1 lần
@export var attack: AttackData

@export_group("Shape")
## Tầm phun tính từ người (m)
@export_range(0.5, 20.0, 0.1) var reach: float = 4.5
## Bề ngang vùng trúng ở cuối tầm (m)
@export_range(0.3, 10.0, 0.1) var width: float = 2.4
@export_range(0.3, 5.0, 0.1) var height: float = 1.8

@export_group("Timing")
## Mốc (giây) lửa bắt đầu phun, khớp lúc vung tay trong animation
@export var active_start: float = 0.16
## Lửa phun liên tục trong khoảng này
@export var active_time: float = 0.5
@export var duration: float = 0.85
## Tính từ lúc kết thúc phun
@export var cooldown: float = 0.5

@export_group("Animation")
## Model cáo chưa có anim phun riêng, tạm dùng anim tung chiêu
@export var animation: StringName = &"Attack_Melee"
@export var anim_speed: float = 1.0


func get_lockout() -> float:
	return duration + cooldown
