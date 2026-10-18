class_name HoverStats
extends Resource
## Thông số bay lơ lửng. Mỗi loại quái bay / boss dùng một file .tres riêng.

## Độ cao gốc thân so với mặt đất bên dưới (m)
@export var hover_height: float = 0.5
## Độ cứng kéo về độ cao đích: vận tốc đứng mong muốn = chênh lệch độ cao × giá trị này (1/s)
@export var vertical_stiffness: float = 8.0
## Vận tốc đứng tối đa do hover tạo ra (m/s): lên bậc / xuống vách không bị giật
@export var max_vertical_speed: float = 4.0
## Gia tốc đứng tối đa của hover (m/s²). Phải nhỏ hơn vertical_response của WindReceiver
## thì cột gió đứng mới nâng được quái bay
@export var vertical_accel: float = 40.0
@export_group("Ground Probe")
## Tia dò đất bắt đầu cao hơn gốc thân chừng này (m), để vẫn thấy đất khi gốc thân lọt dưới mặt bậc
@export var probe_up: float = 0.5
## Độ dài tia dò đất từ điểm bắt đầu trở xuống (m). Hết đất (vực sâu hơn) thì giữ độ cao đất gần nhất
@export var probe_length: float = 6.0
@export_flags_3d_physics var ground_mask: int = 1
