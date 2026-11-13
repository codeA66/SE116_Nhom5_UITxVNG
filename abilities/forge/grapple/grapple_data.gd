class_name GrappleData
extends ForgeSkillData
## Móc kéo (phím G): bắn móc tới vòng móc gần nhất phía trước và bay thẳng tới đó (qua hố). Không có vòng mà
## có quái nhỏ trong tầm phía trước thì kéo quái về phía mình (đẩy qua WindReceiverComponent của quái).

const ID := &"grapple"

@export_group("Aim")
## Tầm tìm vòng móc (m), tính từ tay player tới tâm vòng
@export_range(1.0, 50.0, 0.5) var ring_range: float = 12.0
## Tầm tìm quái để kéo (m)
@export_range(1.0, 50.0, 0.5) var enemy_range: float = 10.0
## Độ rộng cung nhắm phía trước (độ)
@export_range(1.0, 360.0, 1.0) var aim_arc_degrees: float = 120.0
## Độ cao tay bắn móc so với chân
@export var hand_height: float = 1.0
## Lớp tường chắn móc
@export_flags_3d_physics var wall_mask: int = 1

@export_group("Pull")
## Mốc (s) móc bám vào, bắt đầu kéo
@export_range(0.0, 1.0, 0.01) var cast_time: float = 0.12
## Tốc độ bay tới vòng (m/s)
@export_range(1.0, 60.0, 0.5) var pull_speed: float = 16.0
## Gần chân đích bấy nhiêu mét thì coi như tới
@export_range(0.05, 3.0, 0.05) var arrive_distance: float = 0.6
## Cho phép kéo lâu hơn thời gian lý thuyết (quãng / tốc độ) bấy nhiêu giây trước khi buông
@export_range(0.0, 3.0, 0.05) var extra_time: float = 0.4
## Vận tốc thực < pull_speed x hệ số này trong stall_frames frame liên tiếp = bị tường chặn, buông móc
@export_range(0.0, 1.0, 0.05) var stall_ratio: float = 0.25
@export_range(1, 30) var stall_frames: int = 4
## Buông móc: hất lên / tới trước một chút để đáp lên bục
@export var release_up_speed: float = 5.0
@export var release_forward_speed: float = 3.0

@export_group("Enemy pull")
## Quái dừng lại cách player khoảng này (m)
@export_range(0.0, 10.0, 0.1) var enemy_stop_distance: float = 1.5

@export_group("Timing")
## Thời gian đứng ra chiêu khi không bám được gì / khi kéo quái
@export_range(0.05, 2.0, 0.01) var whiff_duration: float = 0.35
@export_range(0.0, 30.0, 0.1) var cooldown: float = 0.6
@export var animation: StringName = &"Bow_Shoot"
@export var anim_speed: float = 1.0
## Dây móc
@export var rope_radius: float = 0.035
@export var rope_color: Color = Color(0.85, 0.55, 0.3, 1)


func get_lockout() -> float:
	return cast_time + cooldown


func get_cos_half_arc() -> float:
	return cos(deg_to_rad(clampf(aim_arc_degrees, 0.0, 360.0) * 0.5)) if aim_arc_degrees < 360.0 else -2.0
