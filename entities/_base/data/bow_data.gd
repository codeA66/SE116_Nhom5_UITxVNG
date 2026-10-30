class_name BowData
extends WeaponData
## Cung là vũ khí phụ: nhặt rồi thì luôn dùng được bằng phím aim (giữ để kéo, thả để bắn), không chiếm ô vũ khí chính.
## Phải kéo tới min_draw_to_shoot mới bắn được; từ đó lực tỉ lệ theo độ kéo. Sát thương gốc, loại sát thương, knockback lấy từ combo[0].

@export_group("Draw")
## Thời gian kéo từ 0 tới đầy dây (s)
@export_range(0.05, 5.0, 0.01, "or_greater") var draw_time: float = 0.5
## Tên clip kéo dây; clip được phát giãn cho vừa draw_time
@export var draw_animation: StringName = &"Bow_Draw"
## Tên clip buông dây sau khi bắn
@export var release_animation: StringName = &"Bow_Release"
## Thời gian đứng thu tay sau khi bắn (s); trong lúc này dash vẫn hủy được
@export_range(0.0, 2.0, 0.01, "or_greater") var release_recovery: float = 0.2
## Độ kéo tối thiểu (0..1) để thả ra là bắn; thả trước mức này thì hủy, không bắn và không tính hồi.
## 1 = phải kéo đầy, 0 = bấm là bắn
@export_range(0.0, 1.0, 0.01) var min_draw_to_shoot: float = 1.0
## Thời gian hồi sau mỗi phát bắn (s, tính từ lúc tên rời dây); trong lúc này không giương cung được.
## Hủy nhắm mà chưa bắn (dash, bị đánh...) không tính hồi
@export_range(0.0, 10.0, 0.01, "or_greater") var shot_cooldown: float = 0.5
## Tốc độ xoay người theo chuột khi đang nhắm; lớn = bám chuột gần như tức thì
@export_range(0.0, 60.0, 0.5, "or_greater") var aim_turn_speed: float = 25.0

@export_group("Shot Power")
## Tỉ lệ tốc độ tên so với projectile_speed khi thả lúc vừa bắt đầu kéo; kéo đầy = 1
@export_range(0.0, 1.0, 0.01) var min_speed_ratio: float = 0.4
## Sát thương khi thả lúc vừa bắt đầu kéo và khi kéo đầy; ở giữa nội suy rồi làm tròn
@export_range(0, 100, 1, "or_greater") var min_damage: int = 1
@export_range(0, 100, 1, "or_greater") var full_damage: int = 2


## Độ kéo 0..1 -> tốc độ tên (m/s)
func get_shot_speed(draw: float) -> float:
	return projectile_speed * lerpf(min_speed_ratio, 1.0, clampf(draw, 0.0, 1.0))


## Độ kéo 0..1 -> sát thương
func get_shot_damage(draw: float) -> int:
	return roundi(lerpf(float(min_damage), float(full_damage), clampf(draw, 0.0, 1.0)))
