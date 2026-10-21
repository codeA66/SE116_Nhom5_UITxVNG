class_name DashData
extends AbilityData
## Thông số dash. Chỉnh trong file .tres, không cần sửa code.

const ID := &"dash"

@export_group("Movement")
@export var speed: float = 14.0
@export var duration: float = 0.18
## Phần vận tốc giữ lại khi kết thúc dash
@export_range(0.0, 1.0) var end_momentum: float = 0.3
## Kết thúc dash mà đang giữ hướng đi thì không chậm hơn tốc độ chạy (tránh tụt tốc rồi tăng lại)
@export var keep_run_speed: bool = true

@export_group("Limits")
## Tính từ lúc kết thúc dash
@export var cooldown: float = 0.4
## Số lần dash trên không trước khi chạm đất
@export var air_dashes: int = 1

@export_group("Animation")
@export var animation: StringName = &"Rig_Medium_MovementAdvanced/Dodge_Forward"
@export var anim_speed: float = 1.0
