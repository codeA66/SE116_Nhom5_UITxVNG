class_name BoatData
extends Resource
## Thông số thuyền buồm chạy bằng gió. Chỉnh trong file .tres, không cần sửa code.

@export_group("Sailing")
## Tốc độ tối đa khi buồm giương (m/s)
@export var sail_speed: float = 5.0
@export var acceleration: float = 3.0
## Bắt đầu giảm tốc khi còn cách bến cuối bấy nhiêu mét, để cập bến êm
@export var arrive_distance: float = 2.5
## Tốc độ thấp nhất khi sắp cập bến, để không đứng khựng trước bến
@export var min_arrive_speed: float = 0.6

@export_group("Shore Push")
## Thổi từ bờ (không có người trên thuyền): thuyền trôi thêm quãng này rồi dừng (m)
@export var shore_push_distance: float = 3.0
@export var shore_push_speed: float = 3.0

@export_group("Wind")
## Hướng thổi lệch khỏi hướng tuyến tối đa bấy nhiêu độ vẫn tính là thổi từ phía sau buồm
@export_range(0.0, 90.0) var max_wind_angle_degrees: float = 60.0

@export_group("Sail")
@export var sail_raise_time: float = 0.35
@export var sail_lower_time: float = 0.5
## Buồm rung khi bị thổi sai hướng
@export var flutter_angle_degrees: float = 8.0
@export var flutter_time: float = 0.4

@export_group("Floating")
## Gốc thuyền cao hơn mặt nước bấy nhiêu mét
@export var float_height: float = 0.1
