class_name MainMenuData
extends Resource
## Thông số menu chính: chữ, màu, nhịp chuyển màn, camera nền. Đổi cảm giác menu chỉ sửa .tres.

@export_group("Text")
## Logo tạm bằng chữ cho tới khi có ảnh logo
@export var title_text: String = "FOXY"
@export var press_any_key_text: String = "Nhấn phím bất kỳ"

@export_group("Palette")
## Chữ đang chọn / tiêu đề
@export var ink_color: Color = Color(0.94, 0.93, 0.89)
## Chữ chưa chọn, chữ phụ
@export var dim_color: Color = Color(0.58, 0.6, 0.63)
## Nét trang trí, viền ô đang chọn
@export var accent_color: Color = Color(0.86, 0.82, 0.7)
## Hành động nguy hiểm (xóa hồ sơ)
@export var danger_color: Color = Color(0.86, 0.38, 0.34)

@export_group("Timing")
## Màn hiện / ẩn (s)
@export_range(0.05, 2.0, 0.01) var screen_fade_time: float = 0.35
## Màn trượt lên bấy nhiêu px khi hiện
@export_range(0.0, 80.0, 1.0) var screen_slide: float = 18.0
## Chu kỳ nhấp nháy dòng "Nhấn phím bất kỳ" (s)
@export_range(0.2, 6.0, 0.05) var prompt_blink_period: float = 2.2
## Logo di chuyển giữa màn tiêu đề và menu (s)
@export_range(0.05, 3.0, 0.01) var logo_move_time: float = 0.7
## Mở game: màn đen sáng dần (s)
@export_range(0.0, 5.0, 0.05) var intro_fade_time: float = 1.6

@export_group("Profiles")
## Tiền hiện trên ô hồ sơ
@export var shown_currency: CurrencyData
@export var empty_slot_text: String = "Hành trình mới"
@export var delete_text: String = "Xóa"
