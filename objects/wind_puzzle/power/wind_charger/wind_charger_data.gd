class_name WindChargerData
extends Resource
## Thông số trụ quạt nạp gió. Chỉnh trong file .tres, không cần sửa code.

@export_group("Lights")
## Số đèn nạp (phải khớp số Charge_Lens trong model)
@export_range(1, 8) var light_count: int = 3
## Mỗi đèn sáng sau bấy nhiêu giây kể từ đèn trước (lúc nạp)
@export_range(0.05, 5.0, 0.05) var light_on_interval: float = 0.4
## Giữ đầy đèn bấy nhiêu giây trước khi bắt đầu tắt
@export_range(0.0, 30.0, 0.1) var hold_time: float = 3.0
## Mỗi đèn tắt sau bấy nhiêu giây kể từ đèn trước (lúc xả)
@export_range(0.05, 5.0, 0.05) var light_off_interval: float = 0.7
@export var lit_color: Color = Color(0.45, 0.95, 1.0)
@export_range(0.0, 16.0, 0.1) var lit_energy: float = 4.0

@export_group("Rotor")
## Trục quay trong toạ độ cục bộ của node Rotor (model v1: cánh nằm trong mặt XY nên quay quanh Z)
@export var rotor_axis: Vector3 = Vector3.BACK
## Tốc độ quay khi đầy gió (độ/giây)
@export var rotor_max_speed: float = 720.0
## Tăng/giảm tốc cánh quạt (độ/giây²)
@export var rotor_acceleration: float = 1440.0

@export_group("Locked Feedback")
## Bị khoá mà bị thổi: cánh giật một góc rồi bật về (độ), báo cánh đang kẹt
@export var jam_jiggle_degrees: float = 9.0
@export_range(0.05, 1.0, 0.01) var jam_jiggle_time: float = 0.28
## Vừa được mở khoá: cánh quay "thức dậy" ở mức này (0..1 tốc độ tối đa) trong bấy nhiêu giây
@export_range(0.0, 1.0, 0.05) var wake_power: float = 0.5
@export_range(0.0, 5.0, 0.05) var wake_time: float = 1.0
