class_name WindData
extends Resource
## Bộ thông số gió dùng chung cho nhiều WindZone.

## Tốc độ gió (m/s). Gió ngang: vận tốc trôi cộng thêm cho vật trong vùng. Gió dọc: tốc độ nâng
@export var strength: float = 4.0

@export_group("Pulse")
## Bật/tắt theo chu kỳ để người chơi canh thời điểm
@export var pulse_enabled: bool = false
@export var on_time: float = 2.0
@export var off_time: float = 2.0
## Thời gian báo hiệu trước khi gió bật lại
@export var warning_time: float = 0.6

@export_group("Visual")
@export var particle_color: Color = Color(0.85, 0.95, 1.0, 0.8)
## Số hạt trên mỗi m³ thể tích vùng gió
@export var particle_density: float = 2.0

@export_group("Updraft Visual")
## Màu riêng cho cột gió (vùng thổi gần thẳng đứng), để phân biệt với gió ngang
@export var updraft_color: Color = Color(0.55, 0.85, 1.0, 0.9)
## Vòng sáng dưới chân cột gió: tốc độ nhấp nháy và độ đậm
@export var ring_pulse_speed: float = 3.0
@export_range(0.0, 1.0) var ring_opacity: float = 0.6
