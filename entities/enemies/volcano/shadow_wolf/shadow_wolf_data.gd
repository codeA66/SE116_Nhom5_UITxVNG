class_name ShadowWolfData
extends EnemyData
## Thông số Sói Bóng Đêm: rình vòng quanh (tan vào bóng tối), vồ từ xa, cắn liên hoàn khi áp sát,
## đi theo bầy (mỗi lúc một con vồ), sợ lửa / ánh sáng. Cú cắn dùng EnemyData.attack (mốc thời gian, sát thương).

@export_group("Stalk")
## Bán kính vòng rình quanh player (m)
@export var stalk_radius: float = 6.0
## Ở xa hơn stalk_radius + khoảng này thì chạy thẳng tới (không rình)
@export var run_in_margin: float = 3.0
## Tốc độ đi vòng khi rình, so với max_speed
@export_range(0.05, 1.0) var stalk_speed_scale: float = 0.45
## Độ tan vào bóng tối lúc rình (0 = hiện rõ, 1 = biến mất hẳn; mắt / răng vẫn sáng)
@export_range(0.0, 1.0, 0.01) var stalk_fade: float = 0.75
## Thời gian mờ / hiện (s)
@export_range(0.0, 2.0, 0.05) var fade_time: float = 0.4

@export_group("Pounce")
## Vồ khi player cách trong khoảng [min, max] (m)
@export var pounce_range_min: float = 3.0
@export var pounce_range_max: float = 7.0
## Gồng người báo trước (s): hiện rõ, mắt sáng, đứng yên
@export var crouch_time: float = 0.5
## Quãng lao tối đa (m) và tốc độ lao (m/s)
@export var pounce_distance: float = 6.0
@export var pounce_speed: float = 13.0
## Đứng sững sau cú vồ (khoảng hở cho player đánh)
@export var recover_time: float = 0.8
@export var pounce_cooldown: float = 2.5
@export var pounce_attack: AttackData

@export_group("Bite")
## Cắn khi player trong khoảng này (m)
@export var bite_range: float = 1.9
## Số cú cắn tối đa mỗi chuỗi
@export_range(1, 6) var bite_combo: int = 3

@export_group("Fear")
## Hệ số sát thương lửa nhận vào (sợ lửa: > 1)
@export_range(0.0, 3.0, 0.05) var fire_damage_multiplier: float = 1.5
## Trúng lửa: hiện rõ và bỏ chạy trong khoảng này (s)
@export var fear_time: float = 1.5
@export_range(0.1, 1.5) var flee_speed_scale: float = 1.0
## Player cầm đuốc đang cháy / đang bốc cháy: sói không vồ, không cắn, rình xa ít nhất khoảng này (m)
@export var light_fear_radius: float = 8.0
