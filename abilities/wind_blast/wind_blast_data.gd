class_name WindBlastData
extends AbilityData
## Thông số kỹ năng thổi gió. Gió không gây sát thương, chỉ đẩy; sát thương đến từ môi trường.
## Chỉnh trong file .tres, không cần sửa code.

const ID := &"wind_blast"

@export_group("Push")
## Vận tốc đẩy ban đầu (m/s), giảm dần theo push_decay của vật nhận gió
@export var push_speed: float = 12.0
## Kích thước vùng thổi trước mặt nhân vật (m)
@export var reach: float = 5.0
@export var width: float = 2.5
@export var height: float = 2.0

@export_group("Timing")
## Mốc (giây) bắt đầu thổi, khớp với lúc vung tay trong animation
@export var active_start: float = 0.12
## Vùng thổi bật trong khoảng này; vật đi vào vùng lúc đang thổi vẫn bị đẩy
@export var active_time: float = 0.12
@export var duration: float = 0.45
## Tính từ lúc kết thúc thổi
@export var cooldown: float = 0.5

@export_group("Animation")
## Model cáo chưa có anim thổi riêng, tạm dùng anim chém ngang
@export var animation: StringName = &"Rig_Medium_CombatMelee/Melee_1H_Attack_Slice_Horizontal"
@export var anim_speed: float = 1.3
