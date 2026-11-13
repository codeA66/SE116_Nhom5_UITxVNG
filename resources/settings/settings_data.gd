class_name SettingsData
extends Resource
## Giá trị mặc định của Cài đặt và danh sách mục hiện trên màn Cài đặt. Autoload Settings đọc file này khi chưa có
## user://settings.cfg và khi người chơi bấm "Khôi phục mặc định". Thêm phím đổi được = thêm một dòng vào rebindable_actions.

@export_group("Âm thanh")
@export_range(0.0, 1.0, 0.05) var master_volume: float = 0.8
@export_range(0.0, 1.0, 0.05) var music_volume: float = 0.8
@export_range(0.0, 1.0, 0.05) var sfx_volume: float = 0.8

@export_group("Hiển thị")
@export var fullscreen: bool = false
@export var vsync: bool = true
## Hệ số nhân độ rung màn hình (0 = tắt rung)
@export_range(0.0, 1.0, 0.05) var screen_shake: float = 1.0

@export_group("Điều khiển")
## Action trong Input Map -> tên hiện trên màn Cài đặt. Thứ tự ở đây là thứ tự dòng.
## Esc (pause, ui_cancel) cố ý không đổi được: người chơi không thể tự khoá mình khỏi menu
@export var rebindable_actions: Dictionary[StringName, String] = {
	&"move_forward": "Đi lên",
	&"move_back": "Đi xuống",
	&"move_left": "Sang trái",
	&"move_right": "Sang phải",
	&"attack": "Tấn công",
	&"aim": "Ngắm cung",
	&"dash": "Lướt",
	# Đánh số, không ghi tên nguyên tố: người chơi chưa tới khu đó thì không bị lộ trước kỹ năng
	&"skill": "Kỹ năng 1",
	&"skill_fire": "Kỹ năng 2",
	&"interact": "Tương tác",
	&"use_item": "Dùng vật phẩm",
	&"inventory": "Túi đồ (Tab)",
	&"help": "Sổ hướng dẫn",
}

@export_group("Ngôn ngữ")
@export var locale: String = "vi"
## Mã ngôn ngữ -> tên hiện trên màn Cài đặt. Thêm ngôn ngữ = thêm bản dịch (.po / .csv) rồi thêm dòng ở đây
@export var languages: Dictionary[String, String] = {"vi": "Tiếng Việt"}
