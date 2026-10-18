class_name DashSlashData
extends Resource
## Thông số đòn "lấy đà -> lướt -> chém" của state DashSlash. Quái khác muốn lướt-chém chỉ cần file .tres mới.

@export_group("Timing")
## Tổng thời gian lấy đà (s): từ lúc hiện báo trước tới lúc bắt đầu lướt
@export var windup_time: float = 0.65
## Quái bám hướng theo player tới mốc này (s); sau mốc này khoá hướng để player né. Bị kẹp trong [0, windup_time]
@export var track_time: float = 0.45

@export_group("Dash")
@export var dash_speed: float = 14.0
## Quãng lướt tối đa (m)
@export var dash_max_distance: float = 3.5
## Dừng lướt khi cách player (vị trí hiện tại) chừng này (m); cũng dùng để tính quãng lướt lúc khoá hướng
@export var stop_distance: float = 1.0
## Lưới an toàn: thời gian lướt tối đa = dash_max_distance / dash_speed + giá trị này (s), phòng kẹt góc
@export var dash_timeout_extra: float = 0.1

@export_group("Safety")
## Dừng lướt khi phía trước hết sàn (mép vực)
@export var stop_at_ledge: bool = true
## Kiểm tra đường thẳng tới player một lần lúc vào state; bị chắn thì huỷ đòn, không hiện báo trước
@export var require_clear_path: bool = true
## Vật cản cách player gần hơn mức này (m) vẫn coi là thông (player đứng sát tường)
@export var path_block_tolerance: float = 0.5
## Độ cao tia kiểm tra tầm nhìn lúc bật hộp chém (m, tính từ chân); ngang ngực để rào thấp vẫn chặn
@export var los_height: float = 0.9
## Lớp chặn tia tầm nhìn: world (1) + player_blocker (256)
@export_flags_3d_physics var los_mask: int = 257

@export_group("Animation")
@export var windup_animation: StringName = &"DashSlash_Windup"
@export var dash_animation: StringName = &"DashSlash_Dash"
