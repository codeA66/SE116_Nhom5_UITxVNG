class_name InventoryStyle
extends Resource
## Thông số màn Tab (màu, cỡ chữ, cỡ ô, nhịp hiệu ứng). Chỉnh trong resources/ui/inventory_style.tres, không sửa code.

@export_group("Màu")
## Chữ / nét chính (ngà), chữ phụ, chữ mờ (lore), nét trang trí
@export var ink: Color = Color(0.94, 0.93, 0.88)
@export var dim: Color = Color(0.62, 0.63, 0.62)
@export var faint: Color = Color(0.45, 0.46, 0.47)
@export var ornament: Color = Color(0.86, 0.84, 0.76, 0.85)
## Nền các ô (trong suốt một phần để lộ cảnh game mờ phía sau)
@export var tile_fill: Color = Color(0.03, 0.035, 0.045, 0.78)
@export var tile_border: Color = Color(0.5, 0.52, 0.52, 0.55)
## Màu báo lỗi / không đủ điều kiện
@export var warning: Color = Color(0.92, 0.45, 0.38)
## Màu "đủ điều kiện" (đủ vật phẩm nâng cấp)
@export var success: Color = Color(0.62, 0.86, 0.66)
## Lớp tối phủ lên cảnh game
@export var backdrop_dim: float = 0.55

@export_group("Cỡ chữ")
@export var title_font: int = 34
@export var tab_font: int = 18
@export var heading_font: int = 16
@export var body_font: int = 18
@export var detail_title_font: int = 30
@export var lore_font: int = 16
@export var key_font: int = 15

@export_group("Kích thước")
## Lề trong của khung trang trí so với mép màn hình (px)
@export var frame_margin: float = 26.0
## Cạnh khung góc hoa văn (px)
@export var corner_size: float = 46.0
@export var detail_width: float = 470.0
@export var element_card_size: Vector2 = Vector2(150, 168)
@export var weapon_socket_size: Vector2 = Vector2(270, 132)
@export var item_tile_size: Vector2 = Vector2(92, 92)
@export var charm_tile_size: Vector2 = Vector2(84, 84)
## Hình minh họa nguyên tố trong bảng chi tiết (cao, px)
@export var detail_art_height: float = 200.0
## Nửa chiều cao viên ngọc cấp trên thẻ nguyên tố / trong lộ trình nâng cấp (px)
@export var level_gem_size: float = 7.5
@export var path_gem_size: float = 9.0
## Biểu tượng vật phẩm cần trong lộ trình nâng cấp (px)
@export var path_icon_size: float = 28.0
## Ô bùa trong hàng "đang đeo"
@export var equipped_tile_size: Vector2 = Vector2(92, 92)
## Số cột lưới bùa
@export var charm_columns: int = 6
## Ô phóng to bấy nhiêu lần khi đang chọn
@export_range(1.0, 1.3, 0.01) var focus_scale: float = 1.08

@export_group("Nhịp (giây)")
@export var open_time: float = 0.22
@export var close_time: float = 0.16
## Trang trượt ngang bao nhiêu px khi đổi trang
@export var page_slide: float = 40.0
@export var page_time: float = 0.22
@export var focus_time: float = 0.12
## Bùa bay giữa lưới và hàng đang đeo
@export var charm_fly_time: float = 0.32
## Ô khắc lần lượt sáng lên: khoảng cách giữa hai ô
@export var notch_step_time: float = 0.07
## Ô rung khi không đổi được (giây, biên độ px)
@export var shake_time: float = 0.3
@export var shake_strength: float = 6.0
## Thẻ nguyên tố lóe sáng khi vừa lên cấp
@export var level_flash_time: float = 0.9

@export_group("Âm thanh")
## Để trống = chưa có file
@export var sound_open: AudioStream
@export var sound_close: AudioStream
@export var sound_move: AudioStream
@export var sound_confirm: AudioStream
@export var sound_page: AudioStream
@export var sound_error: AudioStream
