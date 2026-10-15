class_name WeaponData
extends Resource
## Dữ liệu một vũ khí. Thêm vũ khí mới = thêm file .tres, không sửa code.

@export var display_name: String = ""
## Model gắn vào tay khi cầm và hiển thị khi nằm trên đất
@export var model_scene: PackedScene
## Chuỗi đòn combo, chạy lần lượt từ đầu
@export var combo: Array[AttackData] = []
