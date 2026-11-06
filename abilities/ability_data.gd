class_name AbilityData
extends Resource
## Dữ liệu một kỹ năng mở khóa được (dash, double jump, skill...).
## Kỹ năng cụ thể kế thừa lớp này và thêm thông số riêng.

## Định danh duy nhất, nhân vật dùng để kiểm tra đã mở khóa chưa
@export var id: StringName
@export var display_name: String = ""
@export_group("Acquisition presentation")
@export var icon: Texture2D
@export var accent_color: Color = Color("#a6e0ef")
@export_multiline var description: String = ""
@export var illustration: Texture2D
@export var particle_texture: Texture2D
@export_group("Gameplay")
## Số ô năng lượng mỗi lần dùng (0 = miễn phí, ví dụ Dash)
@export_range(0, 20) var energy_cost: int = 0
