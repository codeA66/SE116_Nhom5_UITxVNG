class_name TeleportData
extends Resource
## Thông số dịch chuyển của quái pháp sư. Chỉnh trong .tres, không cần sửa code.

@export_group("Timing")
## Pha co lại ở chỗ cũ: vẫn đánh được (phần thưởng cho player đã áp sát) (s)
@export var vanish_time: float = 0.35
## Pha biến mất: không đánh được; dấu hiệu hiện ở chỗ sắp xuất hiện (s)
@export var hidden_time: float = 0.45
## Pha hiện ra: đánh được nhưng quái chưa bắn (khoảng hở) (s)
@export var appear_time: float = 0.35
## Hồi tối thiểu giữa hai lần dịch chuyển, tính từ lúc dịch chuyển (s)
@export var cooldown: float = 3.0

@export_group("Point Search")
## Điểm mới nằm trên vòng quanh player trong khoảng bán kính này (m)
@export var ring_min: float = 5.5
@export var ring_max: float = 8.0
## Điểm mới phải cách chỗ cũ ít nhất chừng này (m) để thấy rõ đã dịch chuyển
@export var min_jump_distance: float = 3.0
## Số ứng viên thử tối đa mỗi lần
@export var candidate_count: int = 12
## Phải có đất trong khoảng này bên dưới điểm của player (m): không dịch tới trên vực
@export var max_ground_drop: float = 4.0
## Tia dò đất bắt đầu cao hơn chân player chừng này (m): vẫn thấy bậc cao hơn chỗ player đứng
@export var ground_probe_up: float = 1.0
## Cách mép vùng canh (leash) chừng này (m)
@export var leash_margin: float = 1.0
## Chỉ dịch tới điểm nằm trong khung nhìn camera
@export var require_on_screen: bool = true
## Va chạm kiểm tra điểm kẹt khối (world + enemy + player_blocker)
@export_flags_3d_physics var blocked_mask: int = 261
## Va chạm chặn đường bắn / mặt đất
@export_flags_3d_physics var world_mask: int = 1

@export_group("Visual")
## Tỉ lệ model khi co lại hoàn toàn trước lúc biến mất
@export var vanish_scale: float = 0.1
## Nâng dấu hiệu chỗ hiện ra khỏi mặt đất để không bị nhấp nháy (z-fighting) (m)
@export var marker_ground_offset: float = 0.03
