class_name WeaponData
extends Resource
## Dữ liệu một vũ khí. Thêm vũ khí mới = thêm file .tres, không sửa code.

@export var display_name: String = ""
## Model gắn vào tay khi cầm và hiển thị khi nằm trên đất
@export var model_scene: PackedScene
## Tỉ lệ model khi nằm trên đất (vật phẩm nhặt): model gốc mỗi vũ khí to nhỏ khác nhau, chỉnh để cân đối với nhân vật
@export var model_scale: float = 1.0
## Chuỗi đòn combo, chạy lần lượt từ đầu
@export var combo: Array[AttackData] = []
