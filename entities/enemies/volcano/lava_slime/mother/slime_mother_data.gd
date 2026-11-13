class_name SlimeMotherData
extends LavaSlimeData
## Thông số Slime Mẹ (mini-boss phòng 10 tier 2 map Lửa). Kế thừa LavaSlimeData để dùng lại bước nảy;
## không châm ngòi tự nổ: attack (EnemyData) + explosion_radius là sóng chấn của cú dậm.

@export_group("Slam")
## Thu mình báo trước (s)
@export_range(0.05, 3.0, 0.05) var slam_windup: float = 0.6
## Thời gian bay của cú nhảy dậm (s)
@export_range(0.1, 3.0, 0.05) var slam_air_time: float = 0.8
## Độ cao đỉnh cú nhảy (m)
@export_range(0.0, 10.0, 0.1) var slam_height: float = 3.0
## Nhảy xa tối đa (m): player xa hơn thì đáp ở quãng này theo hướng player
@export_range(0.0, 20.0, 0.1) var slam_max_distance: float = 7.0
## Đứng thở sau khi đáp (s), người chơi đánh trả lúc này
@export_range(0.0, 5.0, 0.05) var slam_recovery: float = 0.9

@export_group("Brood")
## Slime con đẻ ra (scene kế thừa LavaSlime)
@export var child_scene: PackedScene
## Cứ bấy nhiêu giây (lúc đang có mục tiêu) đẻ một lứa
@export_range(0.5, 60.0, 0.5) var brood_interval: float = 8.0
@export_range(0, 8) var brood_count: int = 2
## Tối đa số con đẻ ra còn sống cùng lúc (không tính lúc tách khi chết)
@export_range(0, 16) var max_children: int = 4
## Con xuất hiện quanh mẹ ở khoảng cách này (m)
@export_range(0.0, 6.0, 0.1) var spawn_radius: float = 2.2
## Chết thì tách thành bấy nhiêu con
@export_range(0, 8) var death_split_count: int = 3
