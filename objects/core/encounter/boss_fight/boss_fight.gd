class_name BossFight
extends Node3D
## Trận boss theo phòng: player bước vào Trigger thì boss (boss_scene) xuất hiện tại Spawn và nhắm player.
## Boss phát boss_defeated (Boss1) hoặc died thì lưu cờ persistent_id, phát defeated / activated (nguồn cho cổng,
## FlagReveal cổng ra...). Đã thắng từ trước thì không có boss, is_active() đúng ngay.
## Boss chưa vào cây cho tới khi bắt đầu: không đuổi player từ xa, không tốn xử lý.
## Hiệu năng: chỉ nghe body_entered và signal của boss.

signal started(boss: Node3D)
signal defeated
signal activated

@export var boss_scene: PackedScene
@export var persistent_id: StringName
## Hộp kích hoạt (m), tâm đáy ở gốc node
@export var trigger_size: Vector3 = Vector3(24.0, 4.0, 24.0)
@export_range(0.0, 1.0, 0.05) var defeat_trauma: float = 0.6

var boss: Node3D
var is_defeated: bool = false

@onready var _trigger: Area3D = $Trigger
@onready var _trigger_shape: CollisionShape3D = $Trigger/CollisionShape3D
@onready var _spawn: Marker3D = $Spawn


func _ready() -> void:
	var box: BoxShape3D = (_trigger_shape.shape as BoxShape3D).duplicate() as BoxShape3D
	box.size = trigger_size
	_trigger_shape.shape = box
	_trigger_shape.position = Vector3(0.0, trigger_size.y * 0.5, 0.0)
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		is_defeated = true
		_trigger.monitoring = false
		return
	_trigger.body_entered.connect(_on_body_entered)


func is_active() -> bool:
	return is_defeated


func _on_body_entered(body: Node3D) -> void:
	if boss != null or is_defeated or not body is Player or boss_scene == null:
		return
	_trigger.set_deferred(&"monitoring", false)
	_spawn_boss.call_deferred(body)


func _spawn_boss(player: Node3D) -> void:
	boss = boss_scene.instantiate() as Node3D
	add_child(boss)
	boss.global_transform = _spawn.global_transform
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
