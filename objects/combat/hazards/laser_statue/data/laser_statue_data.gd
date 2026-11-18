class_name LaserStatueData
extends Resource
## Thông số tượng laze kiểu "tia tử thần": phát hiện player trong tầm (có tầm nhìn) → đường cảnh báo trên mặt đất
## nằm dọc hướng tượng → player, xuyên qua chỗ player, bám theo player (aim) → khóa, nháy (lock)
## → đầu tia chạy dọc đường từ phía gần tượng ra phía xa, trúng ai đầu tia đi qua (fire) → nghỉ (cooldown).
## Né: chạy ngang ra khỏi đường trong lúc khóa. Tượng có máu: player đánh vỡ được.

@export_group("Phát hiện")
## Tầm phát hiện tính từ mắt tượng (m)
@export_range(1.0, 60.0, 0.5) var detect_range: float = 14.0
## Lớp vật cản chặn tia và tầm nhìn (mặc định lớp 1 "world")
@export_flags_3d_physics var blocking_mask: int = 1

@export_group("Nhịp")
@export_range(0.1, 10.0, 0.05) var aim_time: float = 1.5
## Tốc độ tâm đường tia đuổi theo player (m/s)
@export_range(0.5, 40.0, 0.5) var track_speed: float = 7.0
@export_range(0.05, 3.0, 0.05) var lock_time: float = 0.45
## Số lần nháy trong lúc khóa
@export_range(1, 12) var lock_flashes: int = 3
## Thời gian đầu tia chạy hết đường (s)
@export_range(0.02, 3.0, 0.01) var sweep_time: float = 0.35
@export_range(0.0, 10.0, 0.05) var cooldown_time: float = 1.5

@export_group("Đường tia")
## Chiều dài đường tia trên mặt đất (m)
@export_range(1.0, 40.0, 0.5) var line_length: float = 10.0
## Bề rộng đường tia = bề rộng vùng trúng (m)
@export_range(0.2, 4.0, 0.05) var line_width: float = 1.0

@export_group("Hình ảnh")
## Bề rộng tia từ mắt xuống: lúc ngắm và lúc quét (m)
@export_range(0.01, 0.5, 0.01) var aim_width: float = 0.06
@export_range(0.05, 2.0, 0.05) var fire_width: float = 0.35
@export var aim_color: Color = Color(1.0, 0.15, 0.05, 0.75)
@export var lock_color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var fire_color: Color = Color(1.0, 0.6, 0.2, 0.9)
## Màu đường cảnh báo trên đất và vệt cháy sau đầu tia
@export var warn_color: Color = Color(1.0, 0.15, 0.05, 0.35)
@export var trail_color: Color = Color(1.0, 0.55, 0.15, 0.8)
## Vệt cháy mờ dần trong bao lâu sau khi quét xong (s)
@export_range(0.0, 3.0, 0.05) var trail_fade_time: float = 0.6

@export_group("Độ bền")
## Máu của tượng (số đòn đánh thường để vỡ, kiếm player gây 1)
@export_range(1, 100) var max_health: int = 6
## Nháy trắng khi bị đánh (s)
@export_range(0.0, 1.0, 0.01) var hit_flash_time: float = 0.1
## Thời gian tượng sụp xuống khi vỡ (s)
@export_range(0.0, 3.0, 0.05) var crumble_time: float = 0.6

@export_group("Sát thương")
@export var damage: int = 1
@export var damage_type: DamageInfo.Type = DamageInfo.Type.FIRE
@export var knockback: float = 8.0
@export_range(0.0, 1.0) var shake_trauma: float = 0.2
