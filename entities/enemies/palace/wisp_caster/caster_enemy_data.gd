class_name CasterEnemyData
extends EnemyData
## Thông số quái đánh xa kiểu pháp sư: giữ khoảng cách, niệm cầu, dịch chuyển.
## Mốc thời gian và sát thương của cú niệm lấy từ EnemyData.attack (AttackData).

@export_group("Keep Distance")
## Cách player gần hơn mức này thì lùi ra, xa hơn max thì lại gần (m)
@export var preferred_min: float = 5.5
@export var preferred_max: float = 8.0
## Tốc độ bay ngang khi đã đứng đúng khoảng, so với max_speed
@export_range(0.0, 1.0) var strafe_speed_scale: float = 0.4
## Đổi chiều bay ngang sau khoảng thời gian ngẫu nhiên trong [min, max] (s)
@export var strafe_switch_min: float = 1.5
@export var strafe_switch_max: float = 3.0

@export_group("Cast")
## Hướng ngắm còn xoay theo player tới mốc này (s), sau đó khoá để player kịp né
@export var aim_lock_time: float = 0.5
## Sau khi hiện ra chưa được niệm trong khoảng này (s): khoảng hở cho player lao tới
@export var post_appear_delay: float = 0.5
## Độ cao nòng bắn trên gốc thân và độ cao ngực player trên gốc chân (m): tia đường bắn nối hai điểm này
@export var muzzle_height: float = 1.1
@export var target_height: float = 1.0
## Kiểm tra đường bắn tối đa một lần mỗi khoảng này (s), không phải mỗi frame
@export var los_check_interval: float = 0.15

@export_group("Teleport Triggers")
## Dịch chuyển sau chừng này quả đã bắn; 0 = tắt điều kiện này
@export var casts_before_teleport: int = 2
## Player ở trong panic_distance liên tục quá panic_time thì dịch chuyển
@export var panic_distance: float = 3.0
@export var panic_time: float = 0.5
## Mất đường bắn liên tục quá khoảng này thì dịch chuyển (s)
@export var no_los_time: float = 1.5
## Vừa trúng đòn thì dịch chuyển (giống Death's Door)
@export var teleport_on_hurt: bool = true

@export_group("Sub Data")
@export var orb: SpiritOrbData
@export var teleport: TeleportData
@export var hover: HoverStats
