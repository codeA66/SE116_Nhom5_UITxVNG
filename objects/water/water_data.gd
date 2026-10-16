@tool
class_name WaterData
extends Resource
## Thông số hình và sóng của một loại nước. Khu khác (Băng, Lửa...) chỉ cần thêm file .tres mới.
## Sóng là tổng 3 lớp sin; Water.get_height_at() trong GDScript tính đúng công thức của shader
## để vật nổi (thuyền) nhấp nhô khớp mặt nước.

@export_group("Colors")
## Sát bờ / nước nông (xanh ngọc sáng)
@export var shallow_color: Color = Color(0.3, 0.88, 0.85, 1.0):
	set(value):
		shallow_color = value
		emit_changed()
## Nước sâu
@export var deep_color: Color = Color(0.06, 0.38, 0.72, 1.0):
	set(value):
		deep_color = value
		emit_changed()
## Mảng sáng và đỉnh sóng
@export var crest_color: Color = Color(0.55, 0.92, 0.95, 1.0):
	set(value):
		crest_color = value
		emit_changed()
@export var foam_color: Color = Color(0.97, 1.0, 1.0, 1.0):
	set(value):
		foam_color = value
		emit_changed()

@export_group("Transparency & Depth")
## Độ đặc sát bờ
@export var shallow_opacity: float = 0.55:
	set(value):
		shallow_opacity = value
		emit_changed()
## Độ đặc nước sâu
@export var deep_opacity: float = 0.97:
	set(value):
		deep_opacity = value
		emit_changed()
## Độ sâu (m) để màu chuyển hẳn từ nông sang sâu
@export var depth_fade_distance: float = 2.5:
	set(value):
		depth_fade_distance = value
		emit_changed()

@export_group("Foam")
## Dải bọt sát bờ / vật (m)
@export var foam_width: float = 0.45:
	set(value):
		foam_width = value
		emit_changed()
## Vệt bọt mảnh thứ hai cách bờ (m)
@export var foam_line_distance: float = 0.9:
	set(value):
		foam_line_distance = value
		emit_changed()
## Bề rộng vệt bọt mảnh (m)
@export var foam_line_width: float = 0.12:
	set(value):
		foam_line_width = value
		emit_changed()
## Kích thước hạt làm mép bọt tơi ra (m)
@export var foam_noise_scale: float = 0.35:
	set(value):
		foam_noise_scale = value
		emit_changed()
## Tốc độ lay của mép bọt
@export var foam_speed: float = 0.4:
	set(value):
		foam_speed = value
		emit_changed()
## Bọt ở mép tấm nước giáp vách (m)
@export var edge_foam_width: float = 0.3:
	set(value):
		edge_foam_width = value
		emit_changed()

@export_group("Surface")
## Kích thước mảng sáng trôi trên mặt nước (m)
@export var patch_scale: float = 5.0:
	set(value):
		patch_scale = value
		emit_changed()
## Độ đậm mảng sáng
@export var patch_opacity: float = 0.12:
	set(value):
		patch_opacity = value
		emit_changed()
## Mật độ đốm lấp lánh trên nước sâu
@export var sparkle_density: float = 0.015:
	set(value):
		sparkle_density = value
		emit_changed()

@export_group("Waves")
## Mỗi lớp sóng: hướng (x, z), bước sóng (m), biên độ (m), tốc độ (m/s). Tổng biên độ ≈ độ cao nhấp nhô
@export var wave_1: Vector4 = Vector4(1.0, 0.3, 6.0, 0.08):
	set(value):
		wave_1 = value
		emit_changed()
@export var wave_1_speed: float = 1.2:
	set(value):
		wave_1_speed = value
		emit_changed()
@export var wave_2: Vector4 = Vector4(-0.4, 1.0, 3.5, 0.05):
	set(value):
		wave_2 = value
		emit_changed()
@export var wave_2_speed: float = 0.9:
	set(value):
		wave_2_speed = value
		emit_changed()
@export var wave_3: Vector4 = Vector4(0.7, -0.7, 1.8, 0.02):
	set(value):
		wave_3 = value
		emit_changed()
@export var wave_3_speed: float = 0.7:
	set(value):
		wave_3_speed = value
		emit_changed()

@export_group("Mesh & Gameplay")
## Khoảng cách giữa các đỉnh lưới mặt nước (m): nhỏ thì sóng mịn hơn nhưng nặng hơn
@export var grid_spacing: float = 0.5:
	set(value):
		grid_spacing = value
		emit_changed()
## Vùng chết bắt đầu thấp hơn mặt nước bấy nhiêu mét, để chạm đỉnh sóng chưa chết ngay
@export var kill_depth_offset: float = 0.3:
	set(value):
		kill_depth_offset = value
		emit_changed()


## Danh sách lớp sóng (hướng chuẩn hóa, bước sóng, biên độ, tốc độ) để shader và GDScript dùng chung một nguồn
func get_waves() -> Array[Vector4]:
	return [wave_1, wave_2, wave_3]


func get_wave_speeds() -> PackedFloat32Array:
	return PackedFloat32Array([wave_1_speed, wave_2_speed, wave_3_speed])
