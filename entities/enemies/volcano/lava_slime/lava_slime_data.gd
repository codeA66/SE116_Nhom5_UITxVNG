class_name LavaSlimeData
extends EnemyData
## Thông số Slime Dung Nham: nảy tới gần player, châm ngòi (phình to, nháy) rồi nổ kiểu Creeper.
## Ngòi châm khi player vào trong EnemyData.attack_range; player ra ngoài fuse_cancel_range thì ngòi xẹp dần.
## Vụ nổ dùng EnemyData.attack (sát thương, loại lửa, đẩy lùi).

@export_group("Hop")
## Mỗi bước nảy dài bao lâu (s): gồm nén - bay - đáp
@export_range(0.2, 3.0, 0.05) var hop_interval: float = 0.6
## Quãng bay mỗi bước (m)
@export_range(0.0, 6.0, 0.05) var hop_distance: float = 1.6
## Phần thời gian bay trong một bước [bắt đầu, kết thúc] (0..1), khớp clip Walk
@export_range(0.0, 1.0, 0.01) var hop_air_start: float = 0.2
@export_range(0.0, 1.0, 0.01) var hop_air_end: float = 0.9

@export_group("Fuse")
## Thời gian ngòi cháy từ 0 tới nổ (s)
@export_range(0.05, 5.0, 0.05) var fuse_time: float = 1.5
## Player ra ngoài khoảng này (m) thì tắt ngòi (ngòi tụt dần, không về 0 ngay)
@export var fuse_cancel_range: float = 4.0
## Thời gian ngòi tụt từ đầy về 0 khi không châm (s)
@export_range(0.05, 10.0, 0.05) var fuse_decay_time: float = 1.5

@export_group("Explosion")
## Bán kính nổ (m)
@export_range(0.1, 12.0, 0.1) var explosion_radius: float = 2.5
## Làm mục tiêu trong vùng nổ bắt lửa
@export var explosion_ignites: bool = true

@export_group("Element")
## Hệ số sát thương lửa nhận vào (kháng lửa: 0)
@export_range(0.0, 2.0, 0.05) var fire_damage_multiplier: float = 0.0
## Không bị bắt lửa
@export var fire_immune: bool = true
