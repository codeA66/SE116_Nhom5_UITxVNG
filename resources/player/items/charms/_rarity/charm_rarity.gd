class_name CharmRarity
extends Resource
## Độ hiếm nằm ở dữ liệu để thêm bậc mới không phải kiểm tra id từng bùa trong UI.

@export_group("Nhận diện")
@export var display_name: String = ""
@export var tint: Color = Color("bc98ed")
@export var highlight: Color = Color("fff0d4")

@export_group("Hiệu ứng tủ đồ")
@export_range(0.0, 1.0, 0.01) var glow_strength: float = 0.65
@export_range(0.0, 2.0, 0.01) var pulse_speed: float = 0.35
@export_range(0, 4) var sparkle_count: int = 3
@export_range(0.0, 0.2, 0.005) var sparkle_size: float = 0.10
