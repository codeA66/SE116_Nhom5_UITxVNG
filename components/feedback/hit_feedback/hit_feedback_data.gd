class_name HitFeedbackData
extends Resource
## Thông số cảm giác khi bị đánh trúng: rung màn hình, tia lửa, máu, co dẹt. Mỗi loại thực thể dùng một .tres.

@export_group("Screen Shake")
@export_range(0.0, 1.0) var trauma: float = 0.18
## Trauma khi đòn bị khiên đỡ (nhỏ hơn: không trúng thịt)
@export_range(0.0, 1.0) var blocked_trauma: float = 0.1

@export_group("Spark")
## Màu tia lửa khi trúng (vàng-cam ấm)
@export var spark_color: Color = Color(1.0, 0.7, 0.25)
## Màu tia khi bị đỡ: ánh kim loại
@export var blocked_spark_color: Color = Color(0.85, 0.93, 1.0)
@export var spark_scale: float = 1.0
## Độ cao điểm trúng so với chân (m)
@export var hit_height: float = 0.9
## Kéo hướng bắn lệch lên trên (0 = đúng hướng đẩy lùi) cho bùng đẹp hơn
@export var upward_bias: float = 0.25
## Đòn có lực đẩy từ mức này trở lên (hoặc đòn kết liễu) tính là đòn mạnh: nhiều nét lực, 2 vòng sóng
@export var strong_knockback: float = 8.0

@export_group("Blood")
## Có chảy máu không (player không, để false)
@export var bleeds: bool = true
## Màu máu: enemy_1 đỏ thẫm, shield_bearer đen dầu, wisp tím hồn...
@export var blood_color: Color = Color(0.45, 0.02, 0.04)
## Nhân kích thước vết máu
@export var blood_scale: float = 1.0
## Hướng phun lệch lên trên so với hướng đòn
@export var blood_upward_bias: float = 0.4

@export_group("Squash")
## Vận tốc "tiếp đất" giả đưa vào SquashStretch (m/s): càng lớn càng dẹt
@export var squash_impact: float = 8.0
