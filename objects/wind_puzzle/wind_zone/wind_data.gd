@tool
class_name WindData
extends Resource
## Bộ thông số gió dùng chung cho nhiều WindZone.

## Tốc độ gió (m/s). Gió ngang: vận tốc trôi cộng thêm cho vật trong vùng. Gió dọc: tốc độ nâng
@export var strength: float = 4.0:
	set(value):
		strength = value
		emit_changed()
## Gió mạnh chặn đường: sức gió lớn hơn tốc độ chạy nên không đi ngược được (chỉ dash qua).
## Hình ảnh chuyển sang kiểu gió mạnh (nét dày đặc, căng, mũi tên dưới đất) để người chơi đọc trước.
## WindZone cảnh báo trong editor nếu cờ này mâu thuẫn với strength.
@export var blocks_player: bool = false:
	set(value):
		blocks_player = value
		emit_changed()

@export_group("Pulse")
## Bật/tắt theo chu kỳ để người chơi canh thời điểm
@export var pulse_enabled: bool = false:
	set(value):
		pulse_enabled = value
		emit_changed()
@export var on_time: float = 2.0:
	set(value):
		on_time = value
		emit_changed()
@export var off_time: float = 2.0:
	set(value):
		off_time = value
		emit_changed()
## Thời gian báo hiệu trước khi gió bật lại
@export var warning_time: float = 0.6:
	set(value):
		warning_time = value
		emit_changed()

## Thời gian truyền từ +Z tới -Z, dùng chung cho lực và VFX.
@export_range(0.02, 3.0) var sweep_time: float = 0.25:
	set(value):
		sweep_time = maxf(value, 0.02)
		emit_changed()
## > 1: đầu gió và hạt tăng tốc dần về phía cuối vùng.
@export_range(1.0, 3.0) var sweep_exponent: float = 1.6:
	set(value):
		sweep_exponent = clampf(value, 1.0, 3.0)
		emit_changed()
## Lực gió tăng dần từ 0 ở mép vùng lên đủ sức trong khoảng này (m), chỉ theo chiều ngang.
## Không có mép mềm thì gió mạnh hơn tốc độ chạy làm người chơi nảy qua lại ở mép vùng. 0 = mép cứng
@export var edge_softness: float = 1.0:
	set(value):
		edge_softness = maxf(value, 0.0)
		emit_changed()

@export_group("Visual")
@export var particle_color: Color = Color(0.97, 0.99, 1.0, 0.95):
	set(value):
		particle_color = value
		emit_changed()
## Số hạt trên mỗi m³ thể tích vùng gió
@export var particle_density: float = 2.0:
	set(value):
		particle_density = value
		emit_changed()

@export_group("Updraft Visual")
## Màu riêng cho cột gió (vùng thổi gần thẳng đứng), để phân biệt với gió ngang
@export var updraft_color: Color = Color(0.97, 0.99, 1.0, 0.95):
	set(value):
		updraft_color = value
		emit_changed()
## Vòng sáng dưới chân cột gió: tốc độ nhấp nháy và độ đậm
@export var ring_pulse_speed: float = 3.0:
	set(value):
		ring_pulse_speed = value
		emit_changed()
@export_range(0.0, 1.0) var ring_opacity: float = 0.6:
	set(value):
		ring_opacity = value
		emit_changed()

@export_group("VFX Style")
## Trống thì VFX dùng wind_vfx_default.tres; các map cũ không cần sửa resource.
@export var vfx_style: WindVfxStyle:
	set(value):
		vfx_style = value
		emit_changed()
