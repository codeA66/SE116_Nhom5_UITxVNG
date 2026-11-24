class_name PlayerDeathData
extends Resource
## Thông số màn player chết: chậm thời gian, camera zoom sát, màn xám trừ quanh cáo, thân tan từ chân lên đầu
## thành hạt màu cáo, rồi tối màn. Chỉnh trong resources/feedback/death/player_death.tres, không sửa code.
## Mọi mốc thời gian tính theo giây thật (không bị chậm theo slow-mo).

@export_group("Chậm thời gian")
## Tốc độ game lúc chết (1 = bình thường) và kéo dài bao lâu
@export_range(0.05, 1.0, 0.01) var slow_scale: float = 0.4
@export_range(0.0, 5.0, 0.05) var slow_time: float = 0.8

@export_group("Camera")
## Camera tiến tới cách cáo bấy nhiêu mét (cố định, để khu có góc nhìn xa như hub vẫn thấy cáo cùng cỡ).
## Camera đang gần hơn mức này thì không lùi ra
@export_range(3.0, 60.0, 0.5) var zoom_distance: float = 15.0
@export_range(0.0, 5.0, 0.05) var zoom_time: float = 1.1

@export_group("Màn xám")
## Độ xám phần ngoài vùng quanh cáo (1 = xám hẳn) và thời gian xám dần
@export_range(0.0, 1.0, 0.01) var grey_amount: float = 0.92
@export_range(0.0, 5.0, 0.05) var grey_time: float = 0.9
## Vùng quanh cáo vẫn giữ màu: bán kính và độ mềm mép (tỉ lệ chiều cao màn)
@export_range(0.0, 1.0, 0.01) var focus_radius: float = 0.1
@export_range(0.01, 1.0, 0.01) var focus_softness: float = 0.12
## Tối viền màn khi xám
@export_range(0.0, 1.0, 0.01) var edge_darkness: float = 0.45

@export_group("Tan biến")
## Chờ bấy nhiêu giây (từ lúc ngã) để cáo nằm hẳn rồi mới tan. Clip ngã bị slow-mo kéo dài:
## clip 1 s + slow 0.8 s ở 0.4x -> nằm hẳn khoảng 1.5 s
@export_range(0.0, 5.0, 0.05) var dissolve_delay: float = 1.65
@export_range(0.1, 6.0, 0.05) var dissolve_time: float = 1.5
## Màu viền sáng ở mép tan
@export var edge_color: Color = Color(1.0, 0.72, 0.38)
## Độ lởm chởm của mép tan (theo tỉ lệ chiều dài thân) và cỡ đốm nhiễu
@export_range(0.0, 0.6, 0.01) var edge_noise: float = 0.18
@export_range(0.0, 0.4, 0.01) var edge_width: float = 0.05
## Độ sáng viền mép tan. Map có glow (map Gió) làm viền loé mạnh: để thấp
@export_range(0.0, 6.0, 0.1) var edge_glow: float = 0.9
@export_range(1.0, 40.0, 0.5) var noise_scale: float = 9.0
## Thân tính từ xương chân tới xương đầu; nới thêm ở hai đầu (m) để tai, đế giày cũng tan hết
@export var foot_bones: PackedStringArray = PackedStringArray(["foot.L", "foot.R"])
@export var head_bone: StringName = &"head"
@export_range(0.0, 1.0, 0.01) var body_margin: float = 0.25

@export_group("Hạt")
## Màu hạt bay ra ở mép tan: lấy theo màu cáo (cam lông, trắng kem, nâu sẫm, xanh khăn)
@export var particle_colors: PackedColorArray = PackedColorArray([
	Color(0.95, 0.52, 0.2), Color(0.98, 0.9, 0.76), Color(0.95, 0.6, 0.28), Color(0.42, 0.26, 0.16), Color(0.4, 0.55, 0.34),
])
## Số hạt mỗi giây lúc tan (giới hạn bởi amount của bộ hạt trong scene)
@export_range(0, 200) var particle_amount: int = 90

@export_group("Kết thúc")
## Tan xong giữ hình bấy nhiêu giây rồi tối màn trong end_fade_time
@export_range(0.0, 3.0, 0.05) var end_hold: float = 0.2
@export_range(0.0, 3.0, 0.05) var end_fade_time: float = 0.5

@export_group("Hồi sinh")
## Màn sáng xong chờ bấy nhiêu giây rồi checkpoint loé, cáo bắt đầu hiện
@export_range(0.0, 3.0, 0.05) var revive_delay: float = 0.3
## Thời gian cáo hiện lại (từ đầu xuống chân)
@export_range(0.1, 6.0, 0.05) var reform_time: float = 1.2
## Tốc độ chạy ngược clip ngã để đứng dậy (1 = bằng lúc ngã); và thời gian chờ cho xong động tác đứng dậy
@export_range(0.1, 4.0, 0.05) var get_up_speed: float = 1.4
@export_range(0.0, 3.0, 0.05) var get_up_time: float = 0.75
## Màn hết xám và camera lùi về khoảng cách thường trong bấy nhiêu giây (bắt đầu lúc đứng dậy)
@export_range(0.0, 3.0, 0.05) var restore_time: float = 0.9
## Bất tử sau khi đứng dậy (s), cáo nhấp nháy
@export_range(0.0, 5.0, 0.05) var invincible_time: float = 1.5
## Hạt tụ về: hút vào tâm mạnh cỡ nào, toả từ vùng rộng cỡ nào (m)
@export_range(0.0, 20.0, 0.1) var gather_pull: float = 4.0
@export_range(0.1, 3.0, 0.05) var gather_radius: float = 0.9


## Tổng thời gian cảnh hồi sinh (s, thời gian thật) tính tới lúc mở điều khiển
func get_revive_duration() -> float:
	return revive_delay + reform_time + maxf(get_up_time, restore_time)
