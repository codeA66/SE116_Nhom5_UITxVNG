class_name WindBurstStyle
extends Resource
## Thông số một hiệu ứng gió một lần: cú thổi, bụi khi trúng vật... Dùng chung một scene WindBurstVfx.
## Kích thước tính bằng mét, thời gian bằng giây.

@export var duration: float = 0.45

@export_group("Strokes")
@export var stroke_count: int = 26
@export var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var edge_color: Color = Color(0.78, 0.9, 1.0, 0.85)
@export var width: float = 0.09
@export var stroke_length: float = 2.6
## Quãng bay của nét; < 0 thì lấy theo tầm thổi của kỹ năng
@export var reach: float = -1.0
## Nửa góc hình nón (độ); 180 = tỏa đều mọi hướng
@export_range(0.0, 180.0) var cone_half_angle_degrees: float = 26.0
@export var shot_height: float = 0.9
@export var height_spread: float = 1.2
@export_range(0.0, 1.0) var ground_fraction: float = 0.4
@export var ground_reach: float = 1.8
@export_range(0.0, 1.0) var curl_fraction: float = 0.2
@export var curl_radius: float = 0.45
@export var curl_turns: float = 0.85

@export_group("Motes")
@export var mote_count: int = 40
@export_range(0.0, 1.0) var leaf_fraction: float = 0.3
@export var leaf_color: Color = Color(0.95, 0.52, 0.18, 1.0)
@export var leaf_color_alt: Color = Color(0.99, 0.72, 0.3, 1.0)
@export var vein_color: Color = Color(0.68, 0.3, 0.1, 1.0)
@export var leaf_size: float = 0.32
@export var speck_size: float = 0.07
## Quãng văng của hạt theo tỉ lệ tầm thổi
@export var mote_reach: float = 0.8
@export var mote_lift: float = 0.8

@export_group("Ring")
## 0 = không có vòng sóng sát đất
@export var ring_radius: float = 2.2
@export var ring_width: float = 0.07

@export_group("Mist")
@export var mist_count: int = 5
@export var mist_color: Color = Color(0.9, 0.95, 1.0, 1.0)
@export_range(0.0, 1.0) var mist_opacity: float = 0.2
@export var mist_size: float = 1.6
@export var mist_spread: float = 1.6

@export_group("Charge")
## 0 = không có phần gồng
@export var charge_strokes: int = 10
@export var charge_radius: float = 1.3
@export var charge_width: float = 0.05
