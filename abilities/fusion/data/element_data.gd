class_name ElementData
extends Resource
## Một nguyên tố ghép được vào vũ khí. Có nguyên tố = đã mở khóa kỹ năng gốc của nó (Gió = Wind Blast).
## Đang ghép vào vũ khí thì kỹ năng gốc bị khóa. Thêm nguyên tố mới = thêm file .tres.

@export var id: StringName
@export var display_name: String = ""
## Kỹ năng gốc: mở khóa kỹ năng này mới có nguyên tố; ghép vào vũ khí thì kỹ năng này không dùng được
@export var ability: AbilityData
## Màu nhận diện (ô tủ đồ, huy hiệu HUD, ánh sáng lúc tụ lực)
@export var color: Color = Color.WHITE
## Để trống thì tủ đồ vẽ chấm màu kèm chữ cái đầu
@export var icon: Texture2D
