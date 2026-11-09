class_name SpawnerCage
extends StaticBody3D
## Lồng sinh quái: khi player ở trong vùng ActiveArea, cứ spawn_interval giây sinh một con (enemy_scene),
## không quá max_alive con còn sống cùng lúc. Player ra khỏi vùng thì ngừng sinh.
## Đánh vỡ lồng (hết máu) thì ngừng sinh hẳn; hạ nốt quái còn lại thì phát cleared và lưu cờ persistent_id.
## Có signal activated + is_active() như nguồn của StoneGate. Thêm loại quái mới chỉ cần đổi enemy_scene.
## Có shield (vật cản đốt được bọc quanh) thì lồng không nhận đòn cho tới khi shield cháy tan.
## Hiệu năng: chỉ dùng Timer + signal (vào/ra vùng, quái chết, lồng hết máu), không có _process.

signal spawned(enemy: Enemy)
signal broken
signal cleared
signal activated

@export var enemy_scene: PackedScene
## Thời gian giữa hai lần sinh (s)
@export_range(0.1, 60.0, 0.1) var spawn_interval: float = 4.0
## Số quái do lồng sinh còn sống tối đa cùng lúc
@export_range(1, 50) var max_alive: int = 3
## Quái xuất hiện trên vòng tròn quanh lồng, bán kính này (m)
@export_range(0.5, 10.0, 0.1) var spawn_radius: float = 2.2
## Vật cản bọc quanh lồng (BurnableBarrier: rào gỗ...). Để trống = chém được ngay
@export var shield: BurnableBarrier
## Cờ lưu khi đã phá lồng và hạ hết quái. Để trống = mỗi lần vào khu lại có lồng
@export var persistent_id: StringName
## Vùng player phải đứng trong để lồng hoạt động (hộp, tâm đáy tại active_area_offset so với lồng)
@export var active_area_size: Vector3 = Vector3(14.0, 4.0, 18.0):
	set(value):
		active_area_size = value.max(Vector3.ONE * 0.5)
		_apply_area()
@export var active_area_offset: Vector3 = Vector3.ZERO:
	set(value):
		active_area_offset = value
		_apply_area()
@export_group("Feedback")
@export_range(0.0, 1.0) var break_trauma: float = 0.35
@export_range(0.01, 0.5) var hit_punch_time: float = 0.12

var is_broken: bool = false
var is_cleared: bool = false

var _alive: int = 0
var _player: Node3D
var _spawn_index: int = 0
var _punch: Tween

@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtboxComponent = $HurtboxComponent
@onready var _area: Area3D = $ActiveArea
@onready var _area_shape: CollisionShape3D = $ActiveArea/CollisionShape3D
@onready var _timer: Timer = $SpawnTimer
@onready var _visual: Node3D = $Visual
@onready var _body_shape: CollisionShape3D = $CollisionShape3D
@onready var _enemies_root: Node3D = $Enemies


func _ready() -> void:
	_apply_area()
	if not persistent_id.is_empty() and GameState.has_flag(persistent_id):
		# Giữ node (không queue_free) để cổng dùng lồng làm nguồn vẫn đọc được is_active()
		is_broken = true
		is_cleared = true
		_visual.hide()
		_body_shape.disabled = true
		_hurtbox.monitorable = false
		_area.monitoring = false
		# Đã dọn thì rào chắc chắn đã cháy: bỏ luôn (rào không tự lưu trạng thái)
		if shield:
			shield.queue_free()
			shield = null
		return
	if shield and not shield.is_burned:
		_hurtbox.monitorable = false
		shield.burned_away.connect(_on_shield_burned, CONNECT_ONE_SHOT)
	_timer.wait_time = spawn_interval
	_timer.timeout.connect(_try_spawn)
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_hurtbox.hurt.connect(_on_hurt)
	_health.died.connect(_break)


func is_active() -> bool:
	return is_cleared


func is_shielded() -> bool:
	return shield != null and not shield.is_burned


func alive_count() -> int:
	return _alive


func _apply_area() -> void:
	if not is_node_ready():
		return
	var box: BoxShape3D = _area_shape.shape as BoxShape3D
	box.size = active_area_size
	_area_shape.position = active_area_offset + Vector3(0.0, active_area_size.y * 0.5, 0.0)


func _on_body_entered(body: Node3D) -> void:
	_player = body
	if is_broken:
		return
	_timer.start(spawn_interval)
	# Sinh ngay con đầu để vào phòng là thấy lồng đang hoạt động. Gọi trễ: đang trong callback vật lý
	# nên không được thêm node có vùng va chạm ngay lúc này
	_try_spawn.call_deferred()


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_timer.stop()


func _try_spawn() -> void:
	if is_broken or enemy_scene == null or _alive >= max_alive:
		return
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	if enemy == null:
		push_warning("SpawnerCage: enemy_scene không phải Enemy")
		return
	# Rải đều quanh lồng theo góc vàng để các con không chồng lên nhau
	var angle: float = float(_spawn_index) * 2.39996
	_spawn_index += 1
	var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius
	_enemies_root.add_child(enemy)
	enemy.global_position = global_position + offset
	_alive += 1
	enemy.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)
	if is_instance_valid(_player):
		enemy.target = _player
	spawned.emit(enemy)


func _on_enemy_died(_enemy: Enemy) -> void:
	_alive -= 1
	if is_broken and _alive <= 0:
		_finish()


func _on_shield_burned() -> void:
	if not is_broken:
		_hurtbox.set_deferred(&"monitorable", true)


func _on_hurt(_info: DamageInfo, _damage_taken: int) -> void:
	if is_broken:
		return
	if _punch:
		_punch.kill()
	_visual.scale = Vector3.ONE * 1.12
	_punch = create_tween()
	_punch.tween_property(_visual, ^"scale", Vector3.ONE, hit_punch_time)


func _break() -> void:
	if is_broken:
		return
	is_broken = true
	_timer.stop()
	_area.set_deferred(&"monitoring", false)
	_hurtbox.set_deferred(&"monitorable", false)
	_body_shape.set_deferred(&"disabled", true)
	if _punch:
		_punch.kill()
	var t: Tween = create_tween()
	t.tween_property(_visual, ^"scale", Vector3(1.3, 0.05, 1.3), 0.25)
	t.tween_callback(_visual.hide)
	if break_trauma > 0.0:
		ScreenShake.add_trauma(break_trauma)
	broken.emit()
	if _alive <= 0:
		_finish()


func _finish() -> void:
	if is_cleared:
		return
	is_cleared = true
	if not persistent_id.is_empty():
		GameState.set_flag(persistent_id)
	cleared.emit()
	activated.emit()
