class_name WeaponData
extends Resource
## Dữ liệu một vũ khí. Thêm vũ khí mới = thêm file .tres, không sửa code.

enum Slot { SWORD, BOW }

@export var slot: Slot = Slot.SWORD

@export var display_name: String = ""
## Model gắn vào tay khi cầm và hiển thị khi nằm trên đất
@export var model_scene: PackedScene
## Tỉ lệ model khi nằm trên đất (vật phẩm nhặt): model gốc mỗi vũ khí to nhỏ khác nhau, chỉnh để cân đối với nhân vật
@export var model_scale: float = 1.0
## Tầm đánh (m): từ tâm nhân vật tới mép xa của hitbox; mọi đòn trong combo dùng chung
@export var attack_range: float = 1.65
## Chuỗi đòn combo, chạy lần lượt từ đầu
@export var combo: Array[AttackData] = []

@export_group("Projectile")
## Để trống cho cận chiến; có scene thì Attack phóng đạn ở active_start.
@export var projectile_scene: PackedScene
@export_range(1.0, 100.0) var projectile_speed: float = 18.0
@export_range(0.1, 10.0) var projectile_lifetime: float = 1.5


func is_ranged() -> bool:
	return projectile_scene != null
