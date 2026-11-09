class_name AbilityChest
extends StaticBody3D
## Rương chứa vật phẩm kỹ năng: bấm tương tác thì nắp bật mở, vật phẩm (AbilityPickup con tên Reward) bay lên
## khỏi rương; bấm tương tác lần nữa để nhận (bảng nhận kỹ năng như sách). Đã nhận rồi thì rương mở sẵn, trống.
## Thêm phần thưởng mới chỉ cần đổi Reward (scene AbilityPickup bất kỳ), không sửa file này.
## Không có Reward: rương trống, mở được; nhớ đã mở bằng persistent_id (nếu đặt).
## Hiệu năng: chỉ nghe signal tương tác, tween khi mở.

signal opened

## Cờ lưu đã mở (dùng cho rương không có Reward; rương có Reward nhớ theo cờ của Reward). Trống = không lưu
@export var persistent_id: StringName
## Nút nắp trong model (xoay quanh trục X cục bộ của nó, bản lề ở mép sau)
@export var lid_path: NodePath = ^"Model/ChestBig_001/Lid_002"
@export_range(-180.0, 180.0, 1.0) var lid_open_degrees: float = -105.0
@export_range(0.05, 3.0, 0.05) var open_time: float = 0.5
## Vật phẩm bay lên từ độ sâu này dưới vị trí nghỉ (m)
@export var reward_rise: float = 0.8

var is_opened: bool = false

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _lid: Node3D = get_node_or_null(lid_path) as Node3D
@onready var _reward: Node3D = get_node_or_null(^"Reward") as Node3D


func _ready() -> void:
	var reward_flag: StringName = _reward.get(&"persistent_id") if _reward else &""
	# Pickup tự xoá khi cờ của nó đã có: rương mở sẵn, trống
	var taken: bool = not reward_flag.is_empty() and GameState.has_flag(reward_flag)
	if taken or (not persistent_id.is_empty() and GameState.has_flag(persistent_id)):
		_open(true)
		return
	if _reward:
		_reward.hide()
		_set_reward_interactable(false)
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(_actor: Node3D) -> void:
	if not is_opened:
		_open(false)


func _open(instant: bool) -> void:
	is_opened = true
	_interactable.enabled = false
	if not instant and not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	var lid_target: float = deg_to_rad(lid_open_degrees)
	if instant:
		if _lid:
			_lid.rotation.x = lid_target
		return
	var tween: Tween = create_tween()
	if _lid:
		tween.tween_property(_lid, ^"rotation:x", lid_target, open_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_reward):
		var rest: Vector3 = _reward.position
		_reward.position = rest - Vector3(0.0, reward_rise, 0.0)
		tween.tween_callback(_reward.show)
		tween.tween_property(_reward, ^"position", rest, open_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_set_reward_interactable.bind(true))
	opened.emit()


func _set_reward_interactable(enabled: bool) -> void:
	if not is_instance_valid(_reward):
		return
	var area: InteractableComponent = _reward.get_node_or_null(^"InteractableComponent") as InteractableComponent
	if area:
		area.enabled = enabled
