class_name EnemyData
extends Resource
## Thông số một loại quái. Thêm loại quái mới = thêm file .tres, không sửa code.

@export var display_name: String = "Quái"
@export var max_health: int = 3
## Tốc độ, gia tốc, trọng lực của quái
@export var movement: MovementStats

@export_group("Sense")
## Player vào trong bán kính này thì bắt đầu đuổi (m)
@export var detect_range: float = 7.0
## Player ra xa hơn bán kính này thì bỏ đuổi, quay về chỗ cũ (m); nên lớn hơn detect_range
@export var lose_range: float = 11.0
## Đi xa chỗ xuất phát hơn mức này thì bỏ đuổi (không đuổi mãi theo player)
@export var leash_range: float = 14.0

@export_group("Attack")
@export var attack: AttackData
## Khoảng cách tới player để bắt đầu ra đòn (m)
@export var attack_range: float = 1.6
## Tầm hộp đòn đánh tính từ tâm quái (m)
@export var hitbox_reach: float = 1.5
## Chờ tối thiểu giữa hai đòn (s): khoảng hở để player phản công
@export var attack_cooldown: float = 1.2

@export_group("Patrol")
## Đi lang thang quanh chỗ xuất phát trong bán kính này (m); 0 = đứng yên canh
@export var patrol_radius: float = 4.0
@export var patrol_wait_min: float = 1.0
@export var patrol_wait_max: float = 2.5
## Tốc độ đi tuần so với tốc độ tối đa
@export_range(0.1, 1.0) var patrol_speed_scale: float = 0.45

@export_group("Hit Reaction")
## Trúng đòn thì bị khựng, ngắt đòn đang ra; tắt cho quái nặng / có giáp
@export var stagger_on_hit: bool = true
@export var stun_time: float = 0.35
## Độ hãm lực đẩy lùi (m/s mỗi giây)
@export var knockback_friction: float = 25.0

@export_group("Wind")
## Hệ số chịu gió: > 1 bay xa (quái nhẹ), 0 = gió không đẩy được (quái nặng)
@export var wind_multiplier: float = 1.0
## Bị cú thổi (kỹ năng gió) trúng thì mất kiểm soát tới khi hết lực đẩy, không tự đi ngược gió
@export var stagger_on_wind: bool = true

@export_group("Death")
## Thời gian xác nằm lại trước khi biến mất (s)
@export var corpse_time: float = 1.2
