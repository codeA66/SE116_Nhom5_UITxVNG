class_name AttackData
extends Resource
## Dữ liệu một đòn đánh. Mọi mốc thời gian tính bằng giây thực, từ lúc bắt đầu đòn.

@export_group("Animation")
@export var animation: StringName
@export var anim_speed: float = 1.0
## Thời gian chuyển từ pose trước sang animation đòn (s); < 0 dùng mặc định của nhân vật.
## 0 = khung ra đòn hiện ngay khi bấm, cảm giác đòn "ăn" phím hơn
@export var blend_in: float = -1.0

@export_group("Animation Markers")
## Tên marker trong animation đánh dấu lúc lưỡi bắt đầu/kết thúc vung qua.
## Có đủ hai marker thì hitbox và vệt chém theo animation (tự khớp khi đổi clip hay anim_speed);
## thiếu marker thì dùng active_start / active_end bên dưới
@export var hit_start_marker: StringName = &"hit_start"
@export var hit_end_marker: StringName = &"hit_end"

@export_group("Damage")
@export var damage: int = 1
@export var damage_type: DamageInfo.Type = DamageInfo.Type.PHYSICAL
@export var knockback: float = 5.0
@export var hitstop: float = 0.05

@export_group("Timing")
## Hitbox bật trong khoảng [active_start, active_end)
@export var active_start: float = 0.15
@export var active_end: float = 0.3
## Từ mốc này có thể nối sang đòn tiếp theo trong combo
@export var combo_window_start: float = 0.3
## Từ mốc này có thể hủy đòn bằng dash (dùng khi có Dash)
@export var cancel_start: float = 0.3
## Từ mốc này, đang giữ hướng đi thì bỏ phần thu đòn để chạy tiếp ngay. < 0 = tắt (chờ hết duration)
@export var move_cancel_start: float = -1.0
## Tổng thời gian đòn, hết thì trở về Idle/Run
@export var duration: float = 0.5

@export_group("Movement")
## Lao nhẹ về trước khi ra đòn
@export var lunge_speed: float = 4.0
@export var lunge_time: float = 0.12
## Hết lunge_time thì không trượt theo quán tính mà dừng hẳn (sau lunge_brake_time): cú lướt gọn
@export var lunge_stop: bool = false
## Có lunge_stop: phanh đều từ lunge_speed về 0 trong bấy nhiêu giây thay vì đứng khựng ngay. 0 = dừng ngay
@export var lunge_brake_time: float = 0.0
## Chém trúng thì người đánh bật lùi nhẹ (m/s, giảm đều về 0 trong self_recoil_time). 0 = không bật lùi
@export var self_recoil_speed: float = 0.0
@export var self_recoil_time: float = 0.1

@export_group("Slash Trail")
## Chiều quét vệt chém cho khớp hướng vung của animation: 1 / -1 cố định. 0 = đổi chiều luân phiên mỗi nhát
@export_range(-1, 1, 1) var slash_trail_direction: int = 0
