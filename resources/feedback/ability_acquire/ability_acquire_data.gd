class_name AbilityAcquireData
extends Resource
## Tham số trình diễn dùng chung; đổi nguyên tố bằng AbilityData, không đổi logic.
@export_group("Phases")
@export var lift_time: float = 1.1
## Nổ ra + lơ lửng (video Hollow Knight: khoảng 0,45–4,2 s)
@export var scatter_time: float = 3.2
## Thu về (video: khoảng 4,4–5,8 s)
@export var gather_time: float = 1.6
@export var breath_time: float = 0.08
@export var burst_time: float = 0.32
@export var settle_time: float = 1.10
## Màn đen trước bảng kỹ năng (video: khoảng 2,5 s), tối dần trong blackout_fade đầu
@export var blackout_time: float = 2.5
@export var blackout_fade: float = 0.6
## Nền đen của bảng nhận kỹ năng phủ kín màn trong thời gian này
@export var panel_time: float = 0.35
@export var fly_time: float = 0.65
@export var slot_time: float = 0.30
## Giữ cho test cũ đọc nhịp bảng; bảng mới sáng dần theo head_fade_time
@export var title_time: float = 0.6
@export var minimum_time: float = 0.001
@export var freeze_world: bool = true
@export var confirm_action: StringName = &"ui_accept"
@export var phase_order: PackedStringArray = PackedStringArray(["Lift","Scatter","Gather","Burst","Settle","Blackout","Reveal"])
## Cho bệ nhận phép tự vẽ năng lượng theo nhịp FSM; sách mặc định vẫn dùng renderer cũ.
@export var continuous_energy: bool = false
@export_group("Absorb")
## Pha Hấp thu (thay Scatter + Gather ở phòng học kỹ năng): dải năng lượng xoắn từ sách cuốn vào ngực,
## vòng co quanh người, cuối pha quả cầu sáng nuốt nhân vật rồi chuyển sang Burst
@export var absorb_time: float = 1.7
@export_range(1, 16) var absorb_stream_count: int = 7
## Số vòng xoắn của mỗi dải trên đường từ sách tới ngực
@export var absorb_stream_turns: float = 1.25
## Bán kính xoắn lớn nhất (m), co về 0 khi tới ngực
@export var absorb_stream_radius: float = 0.9
@export var absorb_stream_width: float = 0.17
## Số đoạn sáng chạy trên mỗi dải và tốc độ chạy (lượt / giây): đọc ra dòng chảy về phía nhân vật
@export var absorb_dashes: float = 3.0
@export var absorb_flow_speed: float = 2.2
## Vòng co quanh người: bán kính đầu / cuối (m)
@export var absorb_ring_radius: Vector2 = Vector2(2.4, 0.35)
@export_range(0, 6) var absorb_ring_count: int = 3
## Quả cầu nuốt nhân vật: bắt đầu ở phần cuối pha (tỉ lệ), bán kính tối đa (m)
@export_range(0.0, 1.0) var absorb_orb_start: float = 0.72
@export var absorb_orb_radius: float = 1.25

@export_group("Actor and book")
@export var visual_path: NodePath = ^"Model/Visual"
@export var fallback_visual_path: NodePath = ^"Model"
@export var lift_height: float = 0.90
@export var face_camera: bool = true
@export var facing_time: float = 0.24
@export_range(0.0, 0.65) var camera_push: float = 0.38
@export var float_amplitude: float = 0.025
@export var float_speed: float = 2.8
@export var book_rise: float = 0.25
@export var book_fade: Vector2 = Vector2(0.15,0.90)
@export var book_edge_strength: float = 0.12
@export_range(0, 16) var book_mote_count: int = 8
@export var book_mote_size: float = 0.045
@export var focus_height: float = 0.65
@export var book_grain: float = 25.0
@export var book_edge: float = 0.075
@export var book_fallback: Color = Color("#9b8871")
@export_group("Ceremony pose")
@export var pose_enabled: bool = true
@export_range(0.0, 1.0) var pose_strength: float = 1.0
@export var landing_squash: float = 0.10
@export var hidden_visual_names: PackedStringArray = PackedStringArray(["Sword","BowHold"])
@export var pose_children: Dictionary[StringName, StringName] = {
	&"upper_arm.L": &"forearm.L", &"forearm.L": &"hand.L",
	&"upper_arm.R": &"forearm.R", &"forearm.R": &"hand.R",
	&"thigh.L": &"shin.L", &"shin.L": &"foot.L",
	&"thigh.R": &"shin.R", &"shin.R": &"foot.R",
}
@export var pose_directions: Dictionary[StringName, Vector3] = {
	&"upper_arm.L": Vector3(0.85,0.35,0.05), &"forearm.L": Vector3(0.45,0.80,0.15),
	&"upper_arm.R": Vector3(-0.85,0.35,0.05), &"forearm.R": Vector3(-0.45,0.80,0.15),
	&"thigh.L": Vector3(0.10,-0.95,0.22), &"shin.L": Vector3(0.03,-0.95,-0.15),
	&"thigh.R": Vector3(-0.10,-0.95,0.22), &"shin.R": Vector3(-0.03,-0.95,-0.15),
}
@export_group("Particles")
## Số đốm tròn (nổ ra, lơ lửng, xoáy thu về)
@export_range(0, 176) var mote_count: int = 160
@export_range(0, 96) var spark_count: int = 32
@export_range(0, 64) var linger_count: int = 24
@export_range(0, 96) var dust_count: int = 8
## Tổng slot hạt tạo sẵn một lần (đốm + tia nhọn); không tạo thêm lúc chạy
@export_range(1, 192) var pool_capacity: int = 192
@export var particle_seed: int = 1701
## Lịch xuất phát theo đợt (test lịch tụ dùng): độ rải các đợt trong pha
@export_range(0.0, 1.0) var gather_stagger: float = 1.0
@export_range(1, 8) var gather_waves: int = 4
@export var gather_flight_time: Vector2 = Vector2(0.60,0.90)
@export var gather_launch_jitter: float = 0.16
@export_range(0.5, 2.0) var gather_wave_overlap: float = 1.6
@export var randomize_gather: bool = true
@export var mote_stretch: float = 5.0
@export var mote_size: float = 0.08
@export var foreground_depth: float = 6.0
@export var spark_radius: float = 4.0
@export var dust_radius: float = 0.55
@export_range(0.1, 0.95) var landing_start: float = 0.78
@export var dust_size: float = 0.14
@export var dust_height: float = 0.06
@export_group("Orbs and spikes")
## Đốm tròn nổ ra: bán kính xa nhất, độ nhanh dừng lại, trôi và lấp lánh khi lơ lửng
@export var orb_radius: float = 4.5
## Cỡ đốm theo phần chiều cao màn hình (camera xa / gần đều thấy rõ)
@export_range(0.001, 0.08, 0.001) var orb_screen_size: float = 0.03
@export var explode_rate: float = 3.5
@export var drift_amp: float = 0.35
@export var drift_speed: float = 0.5
@export var twinkle_speed: float = 3.0
## Phần nhỏ số đốm nằm sát camera: to và mờ
@export_range(0.0, 0.3, 0.01) var foreground_ratio: float = 0.06
@export var foreground_scale: float = 3.5
## Lúc thu về: đốm bay vào vòng xoáy quanh cáo rồi vòng co về tâm
@export var swirl_radius: float = 0.9
@export var swirl_speed: float = 5.0
@export_range(0.1, 1.0, 0.05) var converge_portion: float = 0.7
## Tia sáng nhọn lao thẳng vào cáo trong lúc thu về
@export_range(0, 48) var spike_count: int = 28
@export var spike_life: float = 0.45
@export var spike_start_radius: float = 5.0
@export var spike_length: float = 1.6
@export_range(0.001, 0.08, 0.001) var spike_screen_width: float = 0.03
## Chấm sáng + tia sao tại ngực mỗi khi một tia chạm cáo
@export_range(0.0, 1.0, 0.01) var arrival_time: float = 0.18
@export_range(0.0, 10.0, 0.1) var arrival_size: float = 3.0
## Độ chói khi cộng sáng
@export_range(0.5, 4.0, 0.05) var glow_gain: float = 2.4
## Lóe trắng cả màn lúc hấp thụ (đầu pha nổ ra)
@export_range(0.0, 1.0, 0.01) var scatter_flash: float = 0.85
@export var scatter_flash_time: float = 0.25
## Đợt sau đông hơn đợt trước (lịch bay dùng cho test lịch tụ)
@export_range(0.2, 1.0, 0.05) var wave_density_bias: float = 0.65
## Camera áp sát dần trong lúc tụ: tổng độ áp sát lúc cuối pha (0 = không, 0.8 = phóng ~5 lần)
@export_range(0.0, 0.9, 0.01) var gather_camera_push: float = 0.72
## Vòng sáng trên sàn thu dần về chân cáo trong lúc tụ
@export_range(0.0, 1.0, 0.01) var gather_ring_opacity: float = 0.55
@export var gather_ring_radius: float = 2.6
@export_range(0.001, 0.2, 0.001) var gather_ring_width: float = 0.025
@export_range(1, 6) var gather_ring_count: int = 3
@export var gather_ring_rate: float = 0.7
## Vùng quanh cáo giữ lại bao nhiêu phần độ tối (0.5 = sáng như đèn sân khấu, 1 = tối đều)
@export_range(0.0, 1.0, 0.01) var focus_dim_keep: float = 0.4
## Cáo sáng dần theo lượng năng lượng hút vào, sáng nhất lúc bùng
@export_range(0.0, 4.0, 0.05) var actor_glow_gather: float = 0.9
@export_range(0.0, 4.0, 0.05) var actor_glow_burst: float = 2.2
@export_range(0.5, 8.0, 0.1) var actor_glow_rim_power: float = 2.2
@export_group("Light shapes")
## Tia cứng lúc bùng; 0 = chỉ quầng cầu sáng mềm (như video Hollow Knight)
@export_range(0, 24) var ray_count: int = 0
@export_range(4, 32) var ray_segments: int = 16
@export var ray_length: float = 7.2
@export var ray_width: float = 0.22
@export var burst_expand_time: float = 0.055
@export var burst_flash_time: float = 0.065
@export var ray_decay: float = 2.2
@export var ray_length_variation: float = 0.60
@export var ray_curl: float = 0.025
@export var ray_angle_jitter: float = 1.0
@export var core_size: float = 7.0
@export var charge_core_ratio: float = 0.25
@export var charge_core_opacity: float = 0.12
@export var core_decay: float = 4.0
@export var charge_power: float = 2.0
@export var stream_width: float = 0.055
@export var stream_radius: float = 0.42
@export var stream_height: float = 3.2
@export_range(0.0, 0.98) var stream_compression: float = 0.70
## Sợi sáng xoắn trên đầu cáo lúc tụ; 0 = tắt (nhìn như sợi tóc lạc)
@export_range(0, 24) var stream_count: int = 0
@export var ring_radius: float = 5.2
@export var ring_width: float = 0.012
@export_range(0.0, 1.0) var ring_opacity: float = 0.20
@export var ring_floor: float = 0.035
@export var fallback_accent: Color = Color("#a6e0ef")
@export var hot_color: Color = Color("#f2fcff")
@export var burst_intensity: float = 1.0
@export var maximum_intensity: float = 2.0
@export_group("Screen")
@export var gather_dim: float = 0.45
@export var gather_desaturation: float = 0.65
@export var reveal_dim: float = 0.94
@export var fullscreen_pulse: float = 0.28
@export var gather_pulse: float = 0.025
@export var exposure_gain: float = 0.12
@export var local_radiance: float = 0.06
@export var shock_gain: float = 0.004
@export var shock_width: float = 0.04
@export var focus_radius: float = 0.27
@export_group("Feedback")
@export var shake: float = 0.34
@export var hitstop: float = 0.055
@export_group("UI")
@export var canvas_layer: int = 20
@export var confirm_mouse_button: MouseButton = MOUSE_BUTTON_LEFT
## Cỡ vùng hình minh họa trên bảng (px); đường bay icon cũng cong theo cỡ này
@export var illustration_size: float = 300.0
## Khung hình minh họa ngang: cáo bên trái, hiệu ứng chiêu kéo sang phải (rộng = cao x tỉ lệ này)
@export_range(1.0, 3.0, 0.05) var illustration_aspect: float = 1.9
@export var fly_icon_size: float = 48.0
@export var panel_motes: int = 8
@export var panel_mote_radius: float = 155.0
@export var panel_mote_size: float = 1.8
@export var panel_mote_speed: float = 0.35
@export var pulse_radius: float = 42.0
## Câu hướng dẫn khi kỹ năng không tự đặt acquire_prompt; {key} = hình phím
@export var default_prompt: String = "Nhấn {key} để sử dụng"
@export_group("Panel timing")
## Thứ tự như video Hollow Knight: hình + dòng nhỏ + tên sáng dần từ tối lên trắng (khoảng 1,4 s) -> nét hoa văn -> câu hướng dẫn + mô tả
@export var head_delay: float = 0.1
@export var head_fade_time: float = 1.3
@export var rule_time: float = 0.6
@export var body_pause: float = 0.3
@export var body_fade_time: float = 0.6
## Dấu "có thể đóng" hiện sau chừng này giây kể từ lúc mở bảng
@export var continue_delay: float = 2.8
@export var continue_blink_period: float = 1.2
@export var close_time: float = 0.25
@export_group("Panel text")
@export var verb_font: int = 22
@export var title_font: int = 54
@export var prompt_font: int = 22
@export var key_font: int = 18
@export var body_font: int = 19
## Tâm khối nội dung theo chiều cao màn (0 = mép trên): bảng nằm nửa trên, chừa nhiều khoảng đen như Hollow Knight
@export_range(0.2, 0.8, 0.01) var content_center_y: float = 0.44
@export var description_width: float = 680.0
@export var rule_width: float = 560.0
@export var content_spacing: int = 10
@export var verb_color: Color = Color(0.78, 0.8, 0.8)
@export var title_color: Color = Color(0.97, 0.97, 0.94)
@export var prompt_color: Color = Color(0.9, 0.9, 0.88)
@export var body_color: Color = Color(0.6, 0.63, 0.64)
@export var rule_color: Color = Color(0.86, 0.86, 0.82, 0.8)
@export var key_fill_color: Color = Color(0.06, 0.06, 0.07, 1.0)
@export var key_border_color: Color = Color(0.9, 0.9, 0.86, 0.9)
@export var continue_color: Color = Color(0.86, 0.86, 0.82, 0.7)
@export_group("Panel figure")
## Hình minh họa dựng từ model cáo: khối trắng phát sáng, bóng nhẹ để giữ hình khối (như nhân vật trên bảng Hollow Knight)
@export var figure_resolution: int = 640
## Màu phần khuất sáng của khối trắng
@export var figure_fill_color: Color = Color(0.36, 0.38, 0.42)
@export var figure_line_color: Color = Color(0.96, 0.98, 1.0)
@export var figure_rim_power: float = 2.4
@export var figure_rim_strength: float = 0.6
@export var figure_outline_width: float = 0.008
@export var figure_glow_radius: float = 5.0
@export var figure_glow_strength: float = 0.9
@export var figure_halo_strength: float = 0.22
## Âm = cáo quay sang phải màn hình, hướng về phía hiệu ứng chiêu vẽ bên cạnh
@export var figure_camera_yaw_degrees: float = -75.0
@export var figure_camera_pitch_degrees: float = 8.0
@export var figure_camera_distance: float = 3.4
@export var figure_camera_fov: float = 34.0
@export var figure_look_height: float = 0.82
@export_group("Audio hooks")
@export var audio_descend: AudioStream
@export var audio_gather: AudioStream
@export var audio_burst: AudioStream
@export var audio_panel: AudioStream
@export var audio_icon_land: AudioStream


## Phần áp sát cộng thêm trong pha tụ / bùng / hạ để tổng bằng gather_camera_push (phần theo độ nâng đã có camera_push)
func get_gather_extra_push() -> float:
	return maxf(gather_camera_push-camera_push,0.0)
