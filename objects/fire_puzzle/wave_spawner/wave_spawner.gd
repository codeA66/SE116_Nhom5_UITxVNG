class_name WaveSpawner
extends Node3D
## Sinh quái theo đợt (phòng 09 tier 2 map Lửa): player vào vùng phòng thì sinh một đợt ở các Marker3D con;
## hạ hết đợt thì sau wave_delay giây sinh đợt mới, lặp tới khi nguồn dừng (stop_source, ví dụ WispGroup) bật.
## Dừng thì không sinh thêm; quái còn sống vẫn đánh tiếp. Player ra khỏi phòng: không sinh đợt mới cho tới khi vào lại.
## Hiệu năng: nghe signal (vào / ra phòng, quái chết, nguồn dừng), không có _process.

signal wave_spawned(index: int)
signal stopped

## Quái sinh ra (scene kế thừa Enemy)
@export var enemy_scene: PackedScene
## Vùng phòng (TierZone của RoomFocus)
@export var zone: TierZone
## Nguồn dừng: node có signal activated + hàm is_active() (WispGroup...)
@export var stop_source: Node
## Số quái mỗi đợt (lần lượt các Marker3D con làm chỗ sinh, quay vòng nếu ít chỗ hơn)
@export_range(1, 12) var per_wave: int = 3
@export_range(0.0, 10.0, 0.05) var wave_delay: float = 1.5

var waves: int = 0
var is_stopped: bool = false

var _alive: Array[Enemy] = []
var _player_inside: bool = false
var _points: Array[Marker3D] = []
var _pending: bool = false


func _ready() -> void:
	for child: Node in get_children():
		if child is Marker3D:
			_points.append(child as Marker3D)
	if enemy_scene == null or zone == null or _points.is_empty():
		push_error("%s: thiếu enemy_scene / zone / Marker3D chỗ sinh" % get_path())
		return
	if stop_source and stop_source.has_method(&"is_active") and bool(stop_source.call(&"is_active")):
		is_stopped = true
		return
	if stop_source and stop_source.has_signal(&"activated"):
		stop_source.connect(&"activated", _stop)
	zone.player_entered.connect(_on_player_entered)
	zone.player_exited.connect(_on_player_exited)


func get_alive_count() -> int:
	return _alive.size()


func _on_player_entered() -> void:
	_player_inside = true
	if not is_stopped and _alive.is_empty() and not _pending:
		# Đang trong callback vào / ra của vùng vật lý: thêm quái (có Area3D) phải hoãn tới cuối frame
		_pending = true
		_spawn_wave.call_deferred()


func _on_player_exited() -> void:
	_player_inside = false


func _spawn_wave() -> void:
	_pending = false
	if is_stopped or not _player_inside:
		return
	waves += 1
	for i: int in range(per_wave):
		var point := _points[i % _points.size()]
		var enemy := enemy_scene.instantiate() as Enemy
		get_parent().add_child(enemy)
		enemy.global_position = point.global_position
		_alive.append(enemy)
		enemy.died.connect(_on_enemy_died)
	wave_spawned.emit(waves)


func _on_enemy_died(enemy: Enemy) -> void:
	_alive.erase(enemy)
	if _alive.is_empty() and not is_stopped and not _pending:
		_pending = true
		get_tree().create_timer(wave_delay, false).timeout.connect(_spawn_wave)


func _stop() -> void:
	if is_stopped:
		return
	is_stopped = true
	stopped.emit()
