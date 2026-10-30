@tool
class_name Encounter
extends Node3D
## Trận đánh theo khu (kiểu Death's Door): quái đặt sẵn làm con của node Enemies, đứng ngủ yên trong phòng
## (hoặc ẩn hẳn nếu tắt enemies_visible_before_start). Player bước vào Trigger (và đã có cờ required_flag nếu đặt)
## thì quái lần lượt thức dậy / xuất hiện và lao vào player.
## Giết hết quái thì phát cleared và lưu cờ persistent_id: lần sau vào khu không gặp lại trận đã thắng.
## Thêm loại quái mới chỉ cần đặt scene quái (kế thừa Enemy) dưới Enemies, không sửa file này.

signal started
signal cleared

## Hộp kích hoạt nhỏ hơn mức này không bắt được player (capsule bán kính 0.35)
const MIN_TRIGGER_SIZE := 0.5

## Cờ lưu khi đã dọn xong trận. Để trống = trận xuất hiện lại mỗi lần vào khu
@export var persistent_id: StringName
## Chỉ bắt đầu khi đã có cờ này (ví dụ đã nhặt kiếm). Để trống = bắt đầu ngay khi player bước vào
@export var required_flag: StringName
## Khoảng cách thời gian giữa hai con quái xuất hiện (s); 0 = cùng lúc
@export var spawn_interval: float = 0.35
## Quái đứng sẵn trong phòng (thấy từ xa) nhưng ngủ yên tới khi player vào Trigger.
## Tắt = quái ẩn rồi lần lượt xuất hiện khi trận bắt đầu (kiểu cũ)
@export var enemies_visible_before_start: bool = true
## Quái nhắm player ngay khi xuất hiện thay vì chờ cảm biến phát hiện
@export var aggro_on_start: bool = true
## Hiệu ứng xuất hiện tại chỗ mỗi con quái (tuỳ chọn). Scene nên tự huỷ khi chạy xong
@export var spawn_effect: PackedScene
## Kích thước vùng kích hoạt (m), hộp đặt giữa đáy tại gốc node. Shape là local_to_scene nên mỗi trận chỉnh riêng
@export var trigger_size: Vector3 = Vector3(10.0, 4.0, 10.0):
	set(value):
		trigger_size = value.max(Vector3.ONE * MIN_TRIGGER_SIZE)
		_apply_trigger_size()

@export_group("Clear Feedback")
## Rung màn hình khi giết con cuối của trận
@export_range(0.0, 1.0) var clear_trauma: float = 0.3

var _pending: Array[Enemy] = []
var _alive: int = 0
var _player: Node3D
var _running: bool = false

@onready var _trigger: Area3D = $Trigger
@onready var _enemies_root: Node3D = $Enemies


func _ready() -> void:
	_apply_trigger_size()
	if Engine.is_editor_hint():
		return
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		_enemies_root.queue_free()
		_trigger.queue_free()
		return
	for child in _enemies_root.get_children():
		if child is Enemy:
			_pending.append(child as Enemy)
			if enemies_visible_before_start:
				(child as Enemy).set_dormant(true)
			else:
				# Gỡ khỏi cây: không tốn xử lý, không có va chạm vô hình trước khi trận bắt đầu
				_enemies_root.remove_child(child)
	# Quái đã gỡ khỏi cây thì ShaderWarmup không tự thấy: đưa ra qua get_shader_warmup_sources()
	add_to_group(ShaderWarmup.SOURCE_GROUP)
	_trigger.body_entered.connect(_on_body_entered)
	_trigger.body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	# Quái chưa kịp xuất hiện không có cha: tự giải phóng để không rò bộ nhớ
	for enemy in _pending:
		if is_instance_valid(enemy) and enemy.get_parent() == null:
			enemy.free()
	_pending.clear()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var enemies := get_node_or_null("Enemies")
	if enemies == null or enemies.get_child_count() == 0:
		warnings.append("Chưa có quái dưới node Enemies.")
	return warnings


## ShaderWarmup gọi lúc vào khu: quái chờ trận (chưa nằm trong cây) và hiệu ứng xuất hiện của chúng
func get_shader_warmup_sources() -> Array:
	var sources: Array = []
	sources.append_array(_pending)
	if spawn_effect:
		sources.append(spawn_effect)
	return sources


func is_running() -> bool:
	return _running


func start() -> void:
	if _running or _pending.is_empty():
		return
	_running = true
	_trigger.set_deferred("monitoring", false)
	_disconnect_progress()
	started.emit()
	# Quái đứng sẵn có thể đã bị giết trước khi trận bắt đầu: chỉ đếm con còn sống
	var queue: Array[Enemy] = []
	for enemy in _pending:
		if is_instance_valid(enemy) and not enemy.is_dead():
			queue.append(enemy)
	_pending.clear()
	_alive = queue.size()
	if _alive == 0:
		_finish()
		return
	for enemy: Enemy in queue:
		_spawn(enemy)
		if spawn_interval > 0.0:
			await get_tree().create_timer(spawn_interval, false).timeout
			if not is_inside_tree():
				return


func _spawn(enemy: Enemy) -> void:
	# Chết trong lúc chờ tới lượt (bị đánh khi còn ngủ yên): tính như đã hạ
	if not is_instance_valid(enemy) or enemy.is_dead():
		_count_down()
		return
	enemy.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)
	if enemy.is_inside_tree():
		enemy.set_dormant(false)
		if aggro_on_start and is_instance_valid(_player):
			enemy.target = _player
		return
	_enemies_root.add_child(enemy)
	if aggro_on_start and is_instance_valid(_player):
		enemy.target = _player
	if spawn_effect:
		var fx := spawn_effect.instantiate() as Node3D
		_enemies_root.add_child(fx)
		fx.global_position = enemy.global_position


func _on_body_entered(body: Node3D) -> void:
	_player = body
	if _requirement_met():
		start()
	elif not GameState.progress_changed.is_connected(_on_progress_changed):
		# Player đứng trong vùng trước khi có cờ (ví dụ đi ngang sân kiếm chưa nhặt): chờ cờ mà không quét mỗi frame
		GameState.progress_changed.connect(_on_progress_changed)


func _on_body_exited(body: Node3D) -> void:
	if body == _player and not _running:
		_disconnect_progress()


func _on_progress_changed() -> void:
	if _requirement_met():
		start()


func _requirement_met() -> bool:
	return required_flag.is_empty() or GameState.has_flag(required_flag)


func _disconnect_progress() -> void:
	if GameState.progress_changed.is_connected(_on_progress_changed):
		GameState.progress_changed.disconnect(_on_progress_changed)


func _apply_trigger_size() -> void:
	var shape_node := get_node_or_null("Trigger/CollisionShape3D") as CollisionShape3D
	if shape_node == null or not (shape_node.shape is BoxShape3D):
		return
	(shape_node.shape as BoxShape3D).size = trigger_size
	shape_node.position = Vector3(0.0, trigger_size.y * 0.5, 0.0)


func _on_enemy_died(_enemy: Enemy) -> void:
	_count_down()


func _count_down() -> void:
	_alive -= 1
	if _alive > 0:
		return
	_finish()


func _finish() -> void:
	_running = false
	GameState.set_flag(persistent_id)
	ScreenShake.add_trauma(clear_trauma)
	cleared.emit()
