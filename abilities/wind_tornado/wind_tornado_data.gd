class_name WindTornadoData
extends SkillData
## Thông số Lốc xoáy (dạng cấp 2 của Thổi gió): cơn lốc chạy thẳng, hút quái vào tâm, chạm quái gây sát thương,
## hết quãng đường thì nổ: gây sát thương gió và hất mọi thứ ra xa. Chỉnh trong file .tres, không cần sửa code.

const ID := &"wind_tornado"

@export_group("Travel")
## Lốc hiện ra cách người thả bấy nhiêu mét về phía trước
@export var spawn_offset: float = 1.2
@export var travel_speed: float = 9.0
@export var travel_distance: float = 10.0
## Gặp tường / vật cản thế giới thì nổ sớm thay vì đi xuyên qua
@export var stops_at_walls: bool = true
@export_flags_3d_physics var wall_mask: int = 1

@export_group("Pull")
@export var pull_radius: float = 3.5
## Gia tốc hút về tâm (m/s²); phải lớn hơn push_decay của vật nhận gió thì mới kéo được
@export var pull_accel: float = 40.0
## Trong bán kính này coi như đã ở tâm, thôi hút (không bị kéo qua lại)
@export var hold_radius: float = 0.6

@export_group("Contact")
## Quái vào trong bán kính này bị lốc quẹt trúng (mỗi con một lần mỗi cơn lốc)
@export var contact_radius: float = 1.3
@export var contact_damage: int = 1
## Vật không phải quái (thuyền, cối xay, đạn...) bị lốc đẩy một lần theo hướng lốc chạy, như cú Thổi gió
@export var object_push_speed: float = 12.0

@export_group("Burst")
@export var burst_radius: float = 3.5
@export var burst_damage: int = 1
## Vận tốc hất văng ra khỏi tâm khi nổ (m/s)
@export var burst_push_speed: float = 14.0
## Giữ node sau khi nổ để phần hình tan hết rồi mới trả về pool
@export var linger: float = 0.6

@export_group("Timing")
## Mốc (giây) thả lốc, khớp với lúc vung tay trong animation
@export var release_time: float = 0.16
@export var duration: float = 0.5
## Tính từ lúc kết thúc động tác thả
@export var cooldown: float = 1.0

@export_group("Animation")
@export var animation: StringName = &"Rig_Medium_CombatMelee/Melee_1H_Attack_Slice_Horizontal"
@export var anim_speed: float = 1.2


func get_lockout() -> float:
	return duration + cooldown
