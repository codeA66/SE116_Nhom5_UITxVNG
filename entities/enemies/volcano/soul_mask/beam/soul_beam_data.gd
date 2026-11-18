class_name SoulBeamData
extends Resource
## Thông số chiêu tụ lực bắn tia của Đầu Lửa. Sát thương / đẩy lùi lấy từ EnemyData.attack.

@export_group("Timing")
## Thời gian tụ lực (hàm há dần, vạch cảnh báo hiện) trước khi bắn (s)
@export var charge_time: float = 1.2
## Bao lâu trước lúc bắn thì khoá hướng ngắm, để player kịp né ngang (s); kẹp trong [0, charge_time]
@export var lock_time: float = 0.3
## Tia tồn tại bao lâu (s)
@export var fire_time: float = 0.8
## Khép hàm sau khi bắn trước khi bay tiếp (s)
@export var recover_time: float = 0.6
## Tia nở từ mảnh tới đủ rộng trong khoảng này (s)
@export var grow_time: float = 0.08

@export_group("Shape")
## Bề rộng tia (m), cũng là bề rộng vùng sát thương
@export var width: float = 1.5
## Tầm xa tối đa (m); gặp tường / đất thì dừng ở đó
@export var max_length: float = 16.0
## Vật cản chặn tia
@export_flags_3d_physics var blocking_mask: int = 1
## Ngắm vào điểm cao hơn chân mục tiêu chừng này (m)
@export var target_height: float = 0.9

@export_group("Look")
## Góc há hàm khi tụ lực xong (độ)
@export var jaw_open_degrees: float = 40.0
@export var warn_color: Color = Color(1.0, 0.45, 0.1, 0.35)
@export var beam_color: Color = Color(1.0, 0.55, 0.15, 1.0)
## Màu chớp của vạch cảnh báo trong lúc khoá hướng (ngay trước khi bắn)
@export var lock_color: Color = Color(1.0, 1.0, 1.0, 0.9)
## Số lần chớp trắng trong lock_time; 0 = không chớp
@export_range(0, 12) var lock_flashes: int = 3
## Vạch cảnh báo phình rộng thêm lúc chớp trắng (hệ số so với nửa bề rộng tia)
@export_range(1.0, 3.0, 0.05) var lock_flash_scale: float = 1.4
## Rung màn hình lúc bắn (0 = tắt)
@export_range(0.0, 1.0, 0.01) var fire_trauma: float = 0.25
