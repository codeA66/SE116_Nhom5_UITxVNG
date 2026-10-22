class_name SlashStyle
extends Resource
## Kiểu hình của một nhát chém: vệt chém (chiều quét, độ nghiêng, độ cao, kích thước) và hướng văng
## mảnh / máu khi trúng. Gắn vào AttackData.slash_style; mỗi nhát combo một file .tres để các nhát khác nhau.
## Không đổi góc cung ở đây: đổi góc phải dựng lại mesh mỗi nhát (tốn), nên chỉ đổi những gì xoay / co giãn được.

@export_group("Trail")
## Chiều quét của vệt: 1 / -1 theo chiều vung của animation
@export_range(-1, 1, 2) var sweep_direction: int = 1
## Nghiêng mặt phẳng cung quanh hướng nhìn (độ). Camera nhìn từ trên: nghiêng càng nhiều vệt càng dẹt, trông nhỏ đi
@export_range(0.0, 85.0) var tilt_degrees: float = 16.0
## Cộng thêm vào độ cao vệt so với mặc định của SlashTrail (m)
@export var height_offset: float = 0.0
@export var trail_scale: float = 1.0
## Nhân kích thước sao lóe ở mũi vệt
@export var star_scale: float = 1.0

@export_group("Hit Spray")
## Xoay hướng văng mảnh / máu quanh trục đứng so với hướng đòn (độ). Dương = lệch sang trái người đánh
@export_range(-180.0, 180.0) var spray_angle_degrees: float = 0.0
## Cộng thêm độ hất lên cho mảnh và máu
@export var spray_upward_bias: float = 0.0
## Nhân độ mạnh hiệu ứng trúng (số mảnh, độ xa)
@export var spray_power: float = 1.0

@export_group("Hit Cut")
## Góc nét cắt sáng qua mục tiêu so với hướng đòn (độ, quanh trục đứng). Cố định theo nhát để nét cắt
## cùng chiều vung kiếm; hai nhát vung ngược nhau thì đặt hai góc trái dấu
@export_range(-180.0, 180.0) var cut_angle_degrees: float = 70.0
## Nhân độ dài + bề dày nét cắt
@export var cut_scale: float = 1.0


## Hướng văng khi trúng: xoay hướng đòn theo spray_angle_degrees
func spray_direction(hit_direction: Vector3) -> Vector3:
	return hit_direction.rotated(Vector3.UP, deg_to_rad(spray_angle_degrees))
