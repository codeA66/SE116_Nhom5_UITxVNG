class_name KeyDrop
extends Node3D
## Trận đánh thắng thì rơi chìa ở chỗ con quái cuối gục (chớp sáng, vòng sóng, cột sáng để nhìn từ xa cũng thấy).
## Nạp lại khi đã thắng mà chưa nhặt: chìa nằm sẵn ở vị trí node này (giữa phòng). Đã nhặt rồi: không làm gì.
## Nhiều trận rơi chìa trong một map: mỗi KeyDrop trỏ tới trận của nó bằng tham chiếu, không phát tin chung.

@export var encounter: Encounter
@export var key_scene: PackedScene
## Cờ chìa (cửa có cùng key_id mới mở)
@export var key_id: StringName

@export_group("Hình")
## Chìa bật lên cao bấy nhiêu mét rồi rơi xuống chỗ quái gục
@export var pop_height: float = 1.4
@export_range(0.05, 2.0, 0.05) var pop_time: float = 0.45
@export_range(0.0, 1.0, 0.05) var drop_trauma: float = 0.25
@export var ring_scale: float = 4.0
@export_range(0.05, 3.0, 0.05) var ring_time: float = 0.6
@export_range(0.1, 6.0, 0.1) var beam_time: float = 2.5

var _last_death := Vector3.ZERO
var _has_death := false
var _key: Node3D

@onready var _burst: GPUParticles3D = $Burst
@onready var _ring: MeshInstance3D = $Ring
@onready var _beam: MeshInstance3D = $Beam
@onready var _flash: OmniLight3D = $Flash


func _ready() -> void:
	set_process(false)
	_ring.visible = false
	_beam.visible = false
	_flash.light_energy = 0.0
	if encounter == null or key_scene == null or key_id.is_empty():
		push_warning("%s thiếu encounter / key_scene / key_id: không rơi chìa" % get_path())
		return
	if GameState.has_flag(key_id):
		return
	var won := not encounter.persistent_id.is_empty() and GameState.has_flag(encounter.persistent_id)
	if won:
		# Phòng còn đang dựng node con lúc _ready: thêm chìa vào sau một khung
		_spawn_key.call_deferred(global_position, false)
		return
	encounter.enemy_died.connect(_on_enemy_died)
	encounter.cleared.connect(_on_cleared, CONNECT_ONE_SHOT)


func _on_enemy_died(enemy: Enemy) -> void:
	_last_death = enemy.global_position
	_has_death = true


func _on_cleared() -> void:
	encounter.enemy_died.disconnect(_on_enemy_died)
	# cleared phát giữa lúc engine xử lý va chạm (đòn chém trúng): thêm chìa ngay lúc đó thì Area của chìa không bật được
	_spawn_key.call_deferred(_last_death if _has_death else global_position, true)


func _spawn_key(at: Vector3, with_effect: bool) -> void:
	_key = key_scene.instantiate() as Node3D
	_key.set("key_id", key_id)
	_key.set("persistent_id", key_id)
	get_parent().add_child(_key)
	_key.global_position = at
	_key.tree_exiting.connect(_on_key_leaving)
	if not with_effect:
		return
	_play_drop(at)
	# Chìa bật lên rồi rơi xuống chỗ quái gục
	_key.global_position = at + Vector3.UP * pop_height
	var tween := _key.create_tween()
	tween.tween_property(_key, ^"global_position", at, pop_time).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _play_drop(at: Vector3) -> void:
	global_position = at
	ScreenShake.add_trauma(drop_trauma)
	_burst.restart()
	_ring.visible = true
	_ring.scale = Vector3.ONE * 0.2
	var ring_mat := _ring.get_active_material(0) as ShaderMaterial
	var tween := create_tween().set_parallel()
	tween.tween_property(_ring, ^"scale", Vector3.ONE * ring_scale, ring_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if ring_mat:
		ring_mat.set_shader_parameter(&"intensity", 1.2)
		tween.tween_property(ring_mat, ^"shader_parameter/intensity", 0.0, ring_time)
	_flash.light_energy = 4.0
	tween.tween_property(_flash, ^"light_energy", 0.0, ring_time * 1.5)
	_beam.visible = true
	_beam.scale = Vector3(1.0, 1.0, 1.0)
	tween.tween_property(_beam, ^"scale:x", 0.0, beam_time).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		_ring.visible = false
		_beam.visible = false)


func _on_key_leaving() -> void:
	# Chìa rời cây vì vừa được nhặt (không phải đổi scene): toả hạt tím tại chỗ
	if not GameState.has_flag(key_id) or not is_inside_tree():
		return
	global_position = _key.global_position
	_burst.restart()
	_flash.light_energy = 2.5
	create_tween().tween_property(_flash, ^"light_energy", 0.0, 0.6)
