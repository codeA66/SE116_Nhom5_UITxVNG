class_name CameraCutsceneData
extends Resource
## Nhịp và khung hình của một đoạn cắt cảnh camera. Chỉnh trong .tres, không cần sửa code.

@export_group("Timing")
## Camera trượt từ góc của player tới khung hình (s)
@export_range(0.1, 10.0, 0.05) var travel_time: float = 1.8
## Dừng nhìn mục tiêu (s)
@export_range(0.0, 20.0, 0.05) var hold_time: float = 2.4
## Camera trượt về góc của player (s)
@export_range(0.1, 10.0, 0.05) var return_time: float = 1.4

@export_group("Framing")
## Vị trí camera so với mục tiêu lúc dừng nhìn (m). Góc thấp, chéo một bên cho có chiều sâu
@export var shot_offset: Vector3 = Vector3(-5.0, 3.2, 9.0)
## Nhìn vào điểm cao hơn gốc mục tiêu bấy nhiêu mét (ngang thân "bức tượng")
@export var look_height: float = 1.6
## FOV lúc tới khung hình và lúc kết thúc dừng nhìn: đẩy dần vào (push-in) cho cảm giác điện ảnh
@export_range(10.0, 120.0, 0.5) var shot_fov: float = 46.0
@export_range(10.0, 120.0, 0.5) var push_in_fov: float = 36.0
## Camera trôi ngang quanh mục tiêu trong lúc dừng nhìn (độ), tránh khung hình đứng chết
@export_range(-45.0, 45.0, 0.5) var hold_orbit_degrees: float = 7.0

@export_group("Letterbox")
## Chiều cao mỗi viền đen so với chiều cao màn hình
@export_range(0.0, 0.3, 0.005) var letterbox_ratio: float = 0.11
@export_range(0.05, 3.0, 0.05) var letterbox_time: float = 0.6
