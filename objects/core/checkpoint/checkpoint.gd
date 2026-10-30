@tool
class_name Checkpoint
extends Node3D
## Checkpoint: player đi qua là lưu. Chết sẽ hồi sinh tại điểm xuất hiện của checkpoint này.
## Chỉ một checkpoint sáng tại một thời điểm; hình ảnh do WindShrineVisual quản lý.
## @tool chỉ để hiện cảnh báo cấu hình trong editor.

## Tên checkpoint, duy nhất trong khu; cũng là tên điểm xuất hiện khi hồi sinh
@export var checkpoint_id: StringName:
	set(value):
		checkpoint_id = value
		update_configuration_warnings()
## Giữ tương thích với scene cũ; để trống dùng bảng màu WindShrineStyle.
@export var active_material: Material
## Tốc độ xoay của pha lê (độ/giây)
@export var crystal_spin_speed: float = 12.0

@onready var _trigger: Area3D = $Trigger
@onready var _spawn: SpawnPoint = $Spawn
@onready var _visual: WindShrineVisual = $WindShrineVisual


## Nghe GameState chỉ khi đang ở trong cây (vào lại cây thì nối lại)
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	if not GameState.checkpoint_changed.is_connected(_on_checkpoint_changed):
		GameState.checkpoint_changed.connect(_on_checkpoint_changed)
	if not GameState.progress_replaced.is_connected(_on_progress_replaced):
		GameState.progress_replaced.connect(_on_progress_replaced)


func _ready() -> void:
	_spawn.spawn_id = checkpoint_id
	set_process(false)
	if Engine.is_editor_hint():
		return
	_trigger.body_entered.connect(_on_body_entered)
	_update_visual(true)


## Đổi khu / hồi sinh: scene cũ rời cây trước, cuối frame mới bị xoá. Không ngắt tín hiệu thì checkpoint cũ
## (đã ra khỏi cây) vẫn nhận checkpoint_changed khi player chạm checkpoint ở scene mới -> get_tree() = null
func _exit_tree() -> void:
	# @tool: trong editor GameState không chạy script game, không có signal để ngắt
	if Engine.is_editor_hint():
		return
	if GameState.checkpoint_changed.is_connected(_on_checkpoint_changed):
		GameState.checkpoint_changed.disconnect(_on_checkpoint_changed)
	if GameState.progress_replaced.is_connected(_on_progress_replaced):
		GameState.progress_replaced.disconnect(_on_progress_replaced)


func _get_configuration_warnings() -> PackedStringArray:
	if checkpoint_id.is_empty():
		return ["Chưa đặt Checkpoint Id (tên checkpoint, duy nhất trong khu)."]
	return []


func is_active() -> bool:
	return GameState.get_checkpoint_zone() == _zone_path() and GameState.get_checkpoint_spawn_id() == checkpoint_id


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		GameState.set_checkpoint(_zone_path(), checkpoint_id)


func _on_checkpoint_changed(_zone: String, _spawn_id: StringName) -> void:
	_update_visual()


func _on_progress_replaced() -> void:
	_update_visual(true)


func _update_visual(immediate: bool = false) -> void:
	# Signal nối từ _enter_tree nên có thể tới trước _ready (nạp save lúc vào khu); _ready tự cập nhật sau
	if not is_node_ready():
		return
	_visual.set_active(is_active(), active_material, crystal_spin_speed, immediate)


func _zone_path() -> String:
	return get_tree().current_scene.scene_file_path
