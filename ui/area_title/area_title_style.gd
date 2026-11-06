class_name AreaTitleStyle
extends Resource
## Thông số chữ giới thiệu khu vực (cỡ chữ, màu, nhịp hiện). Bản đầy đủ = lần đầu tới, bản ngắn = các lần sau.

@export_group("Bố cục")
## Tâm khối chữ tính theo chiều cao màn (0 = mép trên, 1 = mép dưới)
@export_range(0.0, 1.0, 0.01) var vertical_anchor: float = 0.3
@export var uppercase_title: bool = true
@export_range(8, 200, 1) var title_font_size: int = 68
@export_range(8, 200, 1) var short_title_font_size: int = 46
@export_range(8, 120, 1) var subtitle_font_size: int = 26
## Bề ngang nét kẻ trang trí (px)
@export_range(40.0, 1600.0, 1.0) var rule_width: float = 560.0
## Chiều cao dải tối sau chữ (px)
@export_range(20.0, 800.0, 1.0) var band_height: float = 240.0

@export_group("Màu")
@export var title_color: Color = Color(0.96, 0.94, 0.88)
@export var subtitle_color: Color = Color(0.8, 0.78, 0.72)
@export var rule_color: Color = Color(0.86, 0.82, 0.7, 0.85)
## Dải tối sau chữ để đọc được trên mọi nền
@export var band_color: Color = Color(0.02, 0.025, 0.035, 0.55)
@export_range(0.0, 1.0, 0.01) var short_band_strength: float = 0.6
## Viền sáng ở mép mực khi chữ đang loang ra
@export var reveal_glow_color: Color = Color(1.0, 0.9, 0.68)

@export_group("Giãn chữ")
## Khoảng cách thêm giữa các chữ (px). Cố định: đổi liên tục theo từng px làm chữ giật
@export_range(-10.0, 60.0, 0.5) var letter_spacing: float = 8.0

@export_group("Nhịp bản đầy đủ (giây)")
## Chờ sau khi được gọi (để màn chuyển cảnh mờ xong)
@export_range(0.0, 5.0, 0.05) var start_delay: float = 0.15
@export_range(0.01, 5.0, 0.05) var rule_time: float = 0.5
@export_range(0.0, 5.0, 0.05) var title_delay: float = 0.05
@export_range(0.01, 5.0, 0.05) var title_reveal_time: float = 0.7
@export_range(0.0, 5.0, 0.05) var subtitle_delay: float = 0.4
@export_range(0.01, 5.0, 0.05) var subtitle_time: float = 0.6
@export_range(0.0, 10.0, 0.05) var hold_time: float = 2.0
@export_range(0.01, 5.0, 0.05) var fade_out_time: float = 0.9

@export_group("Nhịp bản ngắn (giây)")
@export_range(0.01, 5.0, 0.05) var short_reveal_time: float = 0.4
@export_range(0.0, 10.0, 0.05) var short_hold_time: float = 1.0
@export_range(0.01, 5.0, 0.05) var short_fade_out_time: float = 0.6

@export_group("Chuyển động")
## Khối chữ trôi lên bao nhiêu px lúc mờ đi
@export_range(0.0, 200.0, 1.0) var fade_rise: float = 14.0
## Cả khối chữ thu nhẹ từ cỡ này về 1 suốt lúc hiện (cảm giác "thở"). Phóng theo transform nên mượt, không giật
@export_range(0.9, 1.2, 0.005) var zoom_from: float = 1.03
## Vùng mới tới khi chữ cũ đang hiện: chữ cũ tắt nhanh trong thời gian này rồi mới hiện chữ mới
@export_range(0.01, 2.0, 0.01) var interrupt_fade_time: float = 0.3
## Gọi hiện vùng khác trong khoảng này sau lần gọi trước thì gộp luôn, không hiện
## (vừa xuất hiện ở khu là đã đứng trong vùng con, không hiện 2 chữ liền nhau)
@export_range(0.0, 5.0, 0.05) var merge_window: float = 0.6

@export_group("Âm thanh")
## Để trống = chưa có file
@export var full_sound: AudioStream
@export var short_sound: AudioStream
