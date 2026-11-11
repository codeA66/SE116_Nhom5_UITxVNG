class_name FireCasterData
extends EnemyData
## Thông số Quỷ Xương Lửa (pháp sư đi bộ của map lửa): đuổi theo player, vào tầm thì đứng lại niệm rồi bắn cầu lửa.
## Mốc thời gian, sát thương, animation của cú niệm lấy từ EnemyData.attack (AttackData, damage_type FIRE).

@export_group("Chase")
## Đuổi theo player tới khi cách khoảng này (m) và có đường bắn thì đứng lại niệm; bị che thì đuổi tiếp
@export var stop_distance: float = 6.0

@export_group("Cast")
## Hướng ngắm còn xoay theo player tới mốc này (s), sau đó khoá để player kịp né
@export var aim_lock_time: float = 0.5
## Độ cao nòng bắn trên gốc thân và độ cao ngực player trên gốc chân (m)
@export var muzzle_height: float = 1.5
@export var target_height: float = 1.0
## Kiểm tra đường bắn tối đa một lần mỗi khoảng này (s), không phải mỗi frame
@export var los_check_interval: float = 0.15
## Lớp chặn đường bắn (world)
@export_flags_3d_physics var los_mask: int = 1

@export_group("Element")
## Hệ số sát thương lửa nhận vào (0 = kháng hẳn: phun lửa, cầu lửa, TNT lửa không gây sát thương)
@export_range(0.0, 2.0, 0.05) var fire_damage_multiplier: float = 0.0
## Không bắt lửa (không cháy âm ỉ, không hiện lửa trên người)
@export var fire_immune: bool = true

@export_group("Sub Data")
@export var bolt: FireBoltData
