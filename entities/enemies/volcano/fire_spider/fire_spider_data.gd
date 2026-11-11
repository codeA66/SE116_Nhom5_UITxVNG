class_name FireSpiderData
extends EnemyData
## Thông số Nhện Lửa. Cắn nhanh dùng EnemyData.attack (cận chiến, state Attack dùng chung).
## Nhảy vồ và phun tơ là kỹ năng riêng (state kế thừa SpiderSkill): chọn kỹ năng nào thì đọc nhóm tương ứng ở đây.
## Mốc thời gian khớp độ dài clip trong fire_spider.glb (Pounce_Windup 0.83 s, Pounce_Land 0.58 s, WebShot 1.25 s).

@export_group("Pounce")
## Đòn khi đáp xuống: chỉ dùng damage / knockback (vùng sát thương hình cầu quanh chỗ đáp)
@export var pounce_attack: AttackData
## Chỉ nhảy khi player cách trong khoảng [min, max] (m)
@export var pounce_min_range: float = 3.0
@export var pounce_max_range: float = 7.0
## Chờ giữa hai lần nhảy (s)
@export_range(0.0, 60.0, 0.1) var pounce_cooldown: float = 4.0
## Thời gian gồng trước khi nhảy (s): vị trí đáp chốt ở cuối pha này, player kịp né
@export_range(0.1, 3.0, 0.05) var pounce_windup_time: float = 0.8
## Thời gian bay trên không (s)
@export_range(0.1, 2.0, 0.05) var pounce_air_time: float = 0.45
## Thời gian hồi sau khi đáp (s): khoảng hở cho player phản công
@export_range(0.1, 3.0, 0.05) var pounce_land_time: float = 0.6
## Bán kính vùng sát thương lúc đáp (m)
@export_range(0.3, 6.0, 0.1) var pounce_radius: float = 1.6

@export_group("Web Shot")
## Thông số tơ (tốc độ chậm, khóa dash, số nhát xé...)
@export var web: WebData
@export var web_min_range: float = 3.0
@export var web_max_range: float = 8.0
@export_range(0.0, 60.0, 0.1) var web_cooldown: float = 7.0
## Cả cú phun (s) và thời điểm nhả đạn trong đó (s); hướng bắn chốt ở thời điểm này
@export_range(0.2, 4.0, 0.05) var web_duration: float = 1.25
@export_range(0.05, 3.0, 0.05) var web_spit_time: float = 0.45
## Độ cao miệng phun trên gốc thân và độ cao điểm ngắm trên gốc chân player (m)
@export var web_muzzle_height: float = 1.0
@export var web_target_height: float = 0.8

@export_group("Element")
## Hệ số sát thương lửa nhận vào (0 = kháng hẳn như các quái map Lửa khác)
@export_range(0.0, 2.0, 0.05) var fire_damage_multiplier: float = 0.0
## Không bắt lửa
@export var fire_immune: bool = true
