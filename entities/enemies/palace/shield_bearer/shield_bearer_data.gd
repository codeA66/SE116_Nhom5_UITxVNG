class_name ShieldBearerData
extends EnemyData
## Thông số riêng của Hộ Vệ Khiên, thêm vào EnemyData. Loại quái khiên khác = thêm file .tres.

@export_group("Slam")
## Sóng kích phát ra lúc đập khiên
@export var shockwave: ShockwaveData

@export_group("Advance")
## Dừng cách mục tiêu chừng này khi tiến tới (m). Nếu lớn hơn attack_range thì dừng ở attack_range để không kẹt
@export var preferred_distance: float = 2.0

@export_group("Block")
## Khựng bao lâu sau khi chặn một đòn (s)
@export var block_react_time: float = 0.3
## Hệ số đẩy lùi quái khi chặn: knockback của đòn nhân hệ số này
@export var block_pushback_scale: float = 0.25
