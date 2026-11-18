class_name BossFight
extends Node3D
## Trận boss theo phòng: player bước vào Trigger thì boss (boss_scene) xuất hiện tại Spawn và nhắm player.
## Boss phát boss_defeated (Boss1) hoặc died thì lưu cờ persistent_id, phát defeated / activated (nguồn cho cổng,
## FlagReveal cổng ra...). Đã thắng từ trước thì không có boss, is_active() đúng ngay.
## Boss chưa vào cây cho tới khi bắt đầu: không đuổi player từ xa, không tốn xử lý.
## visible_before_start: boss đứng sẵn tại Spawn (tạm dừng xử lý: không đuổi, không đánh, không va chạm), thức khi bắt đầu.
## sight_range > 0: vùng kích hoạt là hình cầu quanh Spawn (tầm nhìn của boss) thay cho hộp trigger_size.
## Hiệu năng: chỉ nghe body_entered và signal của boss.

signal started(boss: Node3D)
signal defeated
signal activated

@export var boss_scene: PackedScene
@export var persistent_id: StringName
## Hộp kích hoạt (m), tâm đáy ở gốc node
@export var trigger_size: Vector3 = Vector3(24.0, 4.0, 24.0)
@export_range(0.0, 1.0, 0.05) var defeat_trauma: float = 0.6
## Chờ bao lâu (s) sau khi player bước vào mới cho boss xuất hiện. 0 = ngay
@export_range(0.0, 10.0, 0.1) var start_delay: float = 0.0
## Boss đứng sẵn trong phòng (ngủ yên) từ lúc vào khu, thức khi trận bắt đầu
@export var visible_before_start: bool = false
## Tầm nhìn của boss (m): player vào trong bán kính này quanh Spawn thì bắt đầu. 0 = dùng hộp trigger_size
@export_range(0.0, 50.0, 0.5) var sight_range: float = 0.0

var boss: Node3D
var is_defeated: bool = false

var _running: bool = false

@onready var _trigger: Area3D = $Trigger
@onready var _trigger_shape: CollisionShape3D = $Trigger/CollisionShape3D
@onready var _spawn: Marker3D = $Spawn


func _ready() -> void:
	if sight_range > 0.0:
		var sphere := SphereShape3D.new()
		sphere.radius = sight_range
		_trigger_shape.shape = sphere
		_trigger_shape.position = _spawn.position
	else:
		var box: BoxShape3D = (_trigger_shape.shape as BoxShape3D).duplicate() as BoxShape3D
		box.size = trigger_size
		_trigger_shape.shape = box
		_trigger_shape.position = Vector3(0.0, trigger_size.y * 0.5, 0.0)
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		is_defeated = true
		_trigger.monitoring = false
		return
	_trigger.body_entered.connect(_on_body_entered)
	if visible_before_start and boss_scene != null:
		_place_boss()
		# Ngủ yên: dừng xử lý (gồm cả va chạm, cảm biến) tới khi trận bắt đầu
		boss.process_mode = Node.PROCESS_MODE_DISABLED


func is_active() -> bool:
	return is_defeated


## Trận đã bắt đầu (boss đã thức / xuất hiện)
func is_running() -> bool:
	return _running


func _on_body_entered(body: Node3D) -> void:
	if _running or is_defeated or not body is Player or boss_scene == null:
		return
	_trigger.set_deferred(&"monitoring", false)
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay, false).timeout
		if not is_inside_tree() or not is_instance_valid(body):
			return
	_spawn_boss.call_deferred(body)


func _place_boss() -> void:
	boss = boss_scene.instantiate() as Node3D
	add_child(boss)
	boss.global_transform = _spawn.global_transform


func _spawn_boss(player: Node3D) -> void:
	if _running or not is_instance_valid(player):
		return
	_running = true
	if boss == null:
		_place_boss()
	boss.process_mode = Node.PROCESS_MODE_INHERIT
	if &"target" in boss:
		boss.set(&"target", player)
	# Boss nghe player_spawned của khu lúc _ready; player đã có sẵn nên gán thẳng mục tiêu
	if &"target_player" in boss:
		boss.set(&"target_player", player)
	if boss.has_signal(&"boss_defeated"):
		boss.connect(&"boss_defeated", _on_boss_defeated, CONNECT_ONE_SHOT)
	elif boss.has_signal(&"died"):
		boss.connect(&"died", _on_boss_defeated.unbind(1), CONNECT_ONE_SHOT)
	started.emit(boss)


func _on_boss_defeated() -> void:
	if is_defeated:
		return
	is_defeated = true
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	if defeat_trauma > 0.0:
		ScreenShake.add_trauma(defeat_trauma)
	defeated.emit()
	activated.emit()
