class_name DialogueStyle
extends Resource
## Thông số hộp thoại NPC (màu, cỡ chữ, kích thước, tốc độ chữ, âm thanh).
## Chỉnh trong resources/ui/dialogue_style.tres, không sửa code.

@export_group("Màu")
@export var text_color: Color = Color(0.94, 0.93, 0.88)
@export var name_color: Color = Color(0.72, 0.72, 0.68)
@export var ornament: Color = Color(0.86, 0.84, 0.76, 0.85)
## Nền hộp (trong suốt một phần để lộ cảnh game)
@export var panel_fill: Color = Color(0.02, 0.025, 0.035, 0.82)
@export var choice_color: Color = Color(0.58, 0.6, 0.63)
@export var choice_focus_color: Color = Color(0.97, 0.96, 0.9)

@export_group("Cỡ chữ")
@export var text_font: int = 22
@export var name_font: int = 16
@export var choice_font: int = 20

@export_group("Kích thước")
## Bề ngang hộp (px); màn hẹp hơn thì tự thu lại vừa màn
@export var box_width: float = 760.0
## Chiều cao tối thiểu vùng chữ: câu ngắn không làm hộp co giật lên xuống
@export var text_min_height: float = 60.0
## Cách mép dưới màn hình (px)
@export var bottom_margin: float = 64.0
## Lề trong hộp: ngang, dọc
@export var padding: Vector2 = Vector2(40.0, 16.0)
@export var rule_height: float = 22.0
## Dấu đứng trước lựa chọn đang chọn
@export var choice_marker: String = "»"

@export_group("Nhịp")
## Số chữ hiện mỗi giây; 0 = hiện cả câu ngay
@export var chars_per_second: float = 45.0
## Dừng thêm sau dấu câu cho nhịp đọc tự nhiên (giây)
@export var punctuation_pause: float = 0.12
@export var open_time: float = 0.18
@export var close_time: float = 0.14
## Hộp trượt lên bấy nhiêu px khi mở
@export var slide: float = 14.0
## Nhịp nhấp nháy dấu "đọc tiếp" (giây)
@export var arrow_pulse_time: float = 0.55

@export_group("Âm thanh")
## Để trống = chưa có file
@export var sound_open: AudioStream
@export var sound_close: AudioStream
## Tiếng lách cách khi chữ hiện
@export var sound_blip: AudioStream
## Cứ bấy nhiêu chữ thì kêu một lần (không kêu mỗi chữ cho đỡ ồn)
@export_range(1, 20, 1) var blip_interval: int = 3
@export var sound_advance: AudioStream
@export var sound_choice_move: AudioStream
@export var sound_choice_confirm: AudioStream
