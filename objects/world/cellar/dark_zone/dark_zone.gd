class_name DarkZone
extends Area3D
## Vùng hầm tối: player bước vào thì nắng, đèn hắt và ánh sáng môi trường tắt dần, chỉ còn quầng sáng nhỏ quanh player
## và các nguồn sáng cục bộ (lò / đuốc đã thắp). Ra khỏi vùng thì sáng lại.
## Vùng là nhiều hộp (boxes, tọa độ thế giới) để phủ phòng và đường nối có hình bất kỳ.
## Hiệu năng: theo dõi player bằng body_entered/exited (đếm số hộp đang chạm), chỉ chạy _physics_process khi player
## ở trong vùng (để quầng sáng bám theo); Tween đổi ánh sáng, không lerp mỗi frame.

signal darkened
signal brightened

## Các hộp phủ vùng tối (AABB theo tọa độ thế giới)
@export var boxes: Array[AABB] = []
@export_group("Ánh sáng bị tắt")
@export var sun: DirectionalLight3D
@export var bounce_light: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export_group("Mức tối")
@export_range(0.0, 1.0, 0.01) var dark_light_ratio: float = 0.0
@export_range(0.0, 1.0, 0.01) var dark_ambient_ratio: float = 0.2
@export_range(0.05, 5.0, 0.05) var fade_time: float = 0.8
@export_group("Làm dịu nguồn sáng bên ngoài")
## Material dùng chung của mặt dung nham ngoài hầm: dịu bớt khi ở trong để bóng tối không bị tương phản gắt. Để trống = bỏ qua
@export var dim_material: ShaderMaterial
@export var dim_parameter: StringName = &"brightness"
@export_range(0.0, 1.0, 0.01) var dim_ratio: float = 0.45
@export_group("Quầng sáng quanh player")
## Tắt khi khu có nguồn sáng mang theo riêng (vd. đuốc cầm tay từ lửa trại)
@export var use_carried_light: bool = true
@export var carried_light_energy: float = 2.4
@export var carried_light_range: float = 6.5
@export var carried_light_color: Color = Color(1.0, 0.62, 0.35)

var is_dark: bool = false

var _player: Node3D
var _inside: int = 0
var _sun_energy: float
var _bounce_energy: float
var _ambient_energy: float
var _dim_base: float = 1.0
var _tween: Tween

@onready var _carried: OmniLight3D = $CarriedLight


func _ready() -> void:
	monitorable = false
	for box: AABB in boxes:
		var shape: CollisionShape3D = CollisionShape3D.new()
		var b: BoxShape3D = BoxShape3D.new()
		b.size = box.size
		shape.shape = b
		add_child(shape)
		shape.global_position = box.get_center()
	_sun_energy = sun.light_energy if sun else 0.0
	_bounce_energy = bounce_light.light_energy if bounce_light else 0.0
	_ambient_energy = world_environment.environment.ambient_light_energy if world_environment else 0.0
	if dim_material:
		var value: Variant = dim_material.get_shader_parameter(dim_parameter)
		_dim_base = float(value) if value != null else 1.0
	_carried.top_level = true
	_carried.light_color = carried_light_color
	_carried.omni_range = carried_light_range
	_carried.light_energy = 0.0
	_carried.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_set_dark(false)
		return
	_carried.global_position = _player.global_position + Vector3(0.0, 1.6, 0.0)


func _exit_tree() -> void:
	# Environment là resource dùng chung: trả lại mức sáng gốc khi rời scene giữa lúc tối
	if world_environment and world_environment.environment:
		world_environment.environment.ambient_light_energy = _ambient_energy
	# Material dung nham cũng dùng chung: trả độ sáng gốc
	if dim_material:
		dim_material.set_shader_parameter(dim_parameter, _dim_base)


## Thể body (player) đi qua chỗ hai hộp chồng nhau vẫn tính là ở trong: đếm số hộp đang chạm
func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	_player = body
	_inside += 1
	if _inside == 1:
		_set_dark(true)


func _on_body_exited(body: Node3D) -> void:
	if body != _player:
		return
	_inside = maxi(_inside - 1, 0)
	if _inside == 0:
		_set_dark(false)


func _set_dark(dark: bool) -> void:
	if dark == is_dark:
		return
	is_dark = dark
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	var k: float = dark_light_ratio if dark else 1.0
	if sun:
		_tween.tween_property(sun, ^"light_energy", _sun_energy * k, fade_time)
	if bounce_light:
		_tween.tween_property(bounce_light, ^"light_energy", _bounce_energy * k, fade_time)
	if world_environment:
		_tween.tween_property(world_environment.environment, ^"ambient_light_energy", _ambient_energy * (dark_ambient_ratio if dark else 1.0), fade_time)
	if dim_material:
		var from: float = float(dim_material.get_shader_parameter(dim_parameter))
		_tween.tween_method(_set_dim, from, _dim_base * (dim_ratio if dark else 1.0), fade_time)
	if use_carried_light:
		_carried.visible = true
		_tween.tween_property(_carried, ^"light_energy", carried_light_energy if dark else 0.0, fade_time)
	set_physics_process(dark and use_carried_light)
	if dark:
		_physics_process(0.0)
		darkened.emit()
	elif use_carried_light:
		_tween.chain().tween_callback(_carried.hide)
		brightened.emit()


func _set_dim(value: float) -> void:
	dim_material.set_shader_parameter(dim_parameter, value)
