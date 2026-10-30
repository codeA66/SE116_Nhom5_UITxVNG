class_name LandingPuff
extends Node3D
## Phía đáp của dịch chuyển: hố xoáy mở trên trời, player chui tọt từ hố rơi xuống, chạm đất thì bụi + vòng sóng
## rồi hố khép lại. Một bản cho mỗi ArenaWarp, dùng lại mãi (không instantiate mỗi lần).
## Chỉ dò chạm đất trong lúc chờ đáp, xong là tắt xử lý.

## Chờ đáp tối đa chừng này giây; quá thì thôi (player bị chặn giữa chừng...)
@export var max_wait: float = 2.0
@export_range(0.05, 2.0, 0.05) var ring_time: float = 0.45
@export_range(0.0, 1.0, 0.01) var land_trauma: float = 0.25

@export_group("Hố trên trời")
@export var sky_radius: float = 1.1
## Hố cao hơn chỗ player xuất hiện bấy nhiêu mét: player hiện ra ngay dưới miệng hố
@export var sky_offset: float = 0.9
## Mở trong lúc màn còn tối (SceneManager.fade_duration) để sáng lên là thấy hố sẵn
@export_range(0.05, 2.0, 0.05) var sky_open_time: float = 0.2
@export_range(0.05, 2.0, 0.05) var sky_close_time: float = 0.35

var _player: Player
var _waited: float = 0.0
var _sky_mat: ShaderMaterial

@onready var _ring: MeshInstance3D = $Ring
@onready var _dust: CPUParticles3D = $Dust
@onready var _sky: MeshInstance3D = $SkyHole


func _ready() -> void:
	# Đặt theo toạ độ thế giới, không đi theo phễu
	set_as_top_level(true)
	_sky.set_as_top_level(true)
	set_physics_process(false)
	_ring.visible = false
	_sky.visible = false
	_sky_mat = (_sky.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	_sky.material_override = _sky_mat
	(_sky.mesh as QuadMesh).size = Vector2.ONE * sky_radius * 2.0
	_sky_mat.set_shader_parameter(&"radius", sky_radius)


## Gọi ngay khi player bước vào phễu (màn đang tối dần): hố trên trời mở sẵn tại điểm đáp
func open_sky(at: Vector3, drop_height: float) -> void:
	global_position = at
	_sky.global_position = at + Vector3.UP * (drop_height + sky_offset)
	_sky.visible = true
	_sky_mat.set_shader_parameter(&"appear", 0.01)
	create_tween().tween_property(_sky_mat, ^"shader_parameter/appear", 1.0, sky_open_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Gọi sau khi player đã được thả: chờ chạm đất để bụi bung và khép hố
func play_on_landing(player: Player, at: Vector3) -> void:
	if not is_instance_valid(player):
		_close_sky()
		return
	global_position = at
	_player = player
	_waited = 0.0
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_waited += delta
	if not is_instance_valid(_player) or _waited > max_wait:
		set_physics_process(false)
		_close_sky()
		return
	if not _player.is_on_floor():
		return
	set_physics_process(false)
	global_position = _player.global_position
	_play()
	_close_sky()


func _play() -> void:
	var mat := _ring.material_override as ShaderMaterial
	mat.set_shader_parameter(&"progress", 0.0)
	_ring.visible = true
	var tween := create_tween()
	tween.tween_property(mat, ^"shader_parameter/progress", 1.0, ring_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_ring.hide)
	_dust.restart()
	if land_trauma > 0.0:
		ScreenShake.add_trauma(land_trauma)


func _close_sky() -> void:
	if not _sky.visible:
		return
	var tween := create_tween()
	tween.tween_property(_sky_mat, ^"shader_parameter/appear", 0.01, sky_close_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(_sky.hide)
