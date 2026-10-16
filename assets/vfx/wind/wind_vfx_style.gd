@tool
class_name WindVfxStyle
extends Resource
## Thông số hình ảnh của vùng gió (luồng ngang và cột gió). Khu khác (ví dụ Băng) chỉ cần thêm file .tres mới.
## Kích thước tính bằng mét; camera game cách ~32 m nên 1 m ≈ 40 px ở 720p.

@export_group("Stroke Colors")
@export var edge_color: Color = Color(0.78, 0.9, 1.0, 0.85):
	set(value):
		edge_color = value
		emit_changed()
@export_range(0.0, 1.0) var stroke_opacity: float = 1.0:
	set(value):
		stroke_opacity = value
		emit_changed()

@export_group("Gust")
## Số nét trên mỗi m² mặt bằng vùng
@export var gust_stroke_density: float = 0.5:
	set(value):
		gust_stroke_density = value
		emit_changed()
@export var gust_max_strokes: int = 40:
	set(value):
		gust_max_strokes = value
		emit_changed()
@export var gust_width: float = 0.09:
	set(value):
		gust_width = value
		emit_changed()
## Chiều dài nét (m)
@export var gust_stroke_length: float = 3.4:
	set(value):
		gust_stroke_length = value
		emit_changed()
@export var gust_travel_speed: float = 12.0:
	set(value):
		gust_travel_speed = value
		emit_changed()
@export_range(0.0, 0.3) var gust_wave: float = 0.04:
	set(value):
		gust_wave = value
		emit_changed()
@export_range(0.0, 1.0) var gust_curl_fraction: float = 0.25:
	set(value):
		gust_curl_fraction = value
		emit_changed()
@export var gust_curl_radius: float = 0.5:
	set(value):
		gust_curl_radius = value
		emit_changed()
@export var gust_curl_turns: float = 0.85:
	set(value):
		gust_curl_turns = value
		emit_changed()

@export_group("Updraft")
@export var updraft_strokes: int = 18:
	set(value):
		updraft_strokes = value
		emit_changed()
@export var updraft_width: float = 0.08:
	set(value):
		updraft_width = value
		emit_changed()
## Chiều dài nét theo tỉ lệ chiều cao cột
@export_range(0.05, 1.0) var updraft_stroke_length: float = 0.4:
	set(value):
		updraft_stroke_length = value
		emit_changed()
@export var updraft_rise_speed: float = 7.0:
	set(value):
		updraft_rise_speed = value
		emit_changed()
@export var updraft_twist_turns: float = 1.1:
	set(value):
		updraft_twist_turns = value
		emit_changed()
@export var updraft_spin_speed: float = 2.2:
	set(value):
		updraft_spin_speed = value
		emit_changed()
## Bán kính đáy/đỉnh phễu theo nửa tiết diện vùng
@export var funnel_bottom: float = 0.8:
	set(value):
		funnel_bottom = value
		emit_changed()
@export var funnel_top: float = 1.0:
	set(value):
		funnel_top = value
		emit_changed()
@export var rise_acceleration: float = 1.5:
	set(value):
		rise_acceleration = value
		emit_changed()

@export_group("Motes")
## Số hạt = WindData.particle_density × thể tích × hệ số này, chặn bởi max_motes
@export var mote_density_ratio: float = 0.6:
	set(value):
		mote_density_ratio = value
		emit_changed()
@export var max_motes: int = 90:
	set(value):
		max_motes = value
		emit_changed()
@export_range(0.0, 1.0) var leaf_fraction: float = 0.35:
	set(value):
		leaf_fraction = value
		emit_changed()
@export var leaf_color: Color = Color(0.95, 0.52, 0.18, 1.0):
	set(value):
		leaf_color = value
		emit_changed()
@export var leaf_color_alt: Color = Color(0.99, 0.72, 0.3, 1.0):
	set(value):
		leaf_color_alt = value
		emit_changed()
@export var vein_color: Color = Color(0.68, 0.3, 0.1, 1.0):
	set(value):
		vein_color = value
		emit_changed()
@export var speck_color: Color = Color(1.0, 1.0, 1.0, 0.95):
	set(value):
		speck_color = value
		emit_changed()
@export var leaf_size: float = 0.32:
	set(value):
		leaf_size = value
		emit_changed()
@export var speck_size: float = 0.08:
	set(value):
		speck_size = value
		emit_changed()
@export var mote_speed: float = 6.0:
	set(value):
		mote_speed = value
		emit_changed()
@export var mote_flutter: float = 0.35:
	set(value):
		mote_flutter = value
		emit_changed()
@export var leaf_tumble_speed: float = 6.0:
	set(value):
		leaf_tumble_speed = value
		emit_changed()

@export_group("Mist")
@export var mist_count: int = 5:
	set(value):
		mist_count = value
		emit_changed()
@export var mist_color: Color = Color(0.9, 0.95, 1.0, 1.0):
	set(value):
		mist_color = value
		emit_changed()
@export_range(0.0, 1.0) var mist_opacity: float = 0.1:
	set(value):
		mist_opacity = value
		emit_changed()
@export var mist_size: float = 2.2:
	set(value):
		mist_size = value
		emit_changed()
@export var mist_speed: float = 1.5:
	set(value):
		mist_speed = value
		emit_changed()

@export_group("Ground")
@export var ground_color: Color = Color(0.85, 0.94, 1.0, 1.0):
	set(value):
		ground_color = value
		emit_changed()
@export_range(0.0, 1.0) var ground_opacity: float = 0.4:
	set(value):
		ground_opacity = value
		emit_changed()
## Số hàng vạch trên mỗi mét bề ngang vùng
@export var ground_rows_per_meter: float = 1.6:
	set(value):
		ground_rows_per_meter = value
		emit_changed()
## Bề rộng vạch gió dưới đất (m)
@export var ground_line_width: float = 0.05:
	set(value):
		ground_line_width = value
		emit_changed()
@export var ground_dash_speed: float = 6.0:
	set(value):
		ground_dash_speed = value
		emit_changed()
@export_range(0.0, 1.0) var ground_fill_opacity: float = 0.12:
	set(value):
		ground_fill_opacity = value
		emit_changed()
@export var ring_spin: float = 1.2:
	set(value):
		ring_spin = value
		emit_changed()
## Nhích dấu mặt đất lên khỏi sàn để không nhấp nháy (z-fighting)
@export var ground_offset: float = 0.03:
	set(value):
		ground_offset = value
		emit_changed()
