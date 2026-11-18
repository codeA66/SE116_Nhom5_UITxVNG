class_name CoolingPath
extends Area3D
## Theo dõi player vào/ra bằng signal, chỉ kiểm tra nhiệt khi có người trên đá.

signal failed(player: Player)
signal heat_changed

enum Heat { HOT, COLD, WARNING, SAFE }

const MAGMA_SHADER: Shader = preload("res://levels/zone_3_fire/level_3/rooms/tier_3/puzzles/cooling_path/magma_path.gdshader")

@export var surfaces: Array[MeshInstance3D] = []

var heat: Heat = Heat.HOT
var _data: KhamPuzzleData
var _warning_time: float = 0.0
var _players: Array[Player] = []
var _material: ShaderMaterial
var _warning_tween: Tween

@onready var _timer: Timer = $HeatTimer


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = MAGMA_SHADER
	for surface: MeshInstance3D in surfaces:
		surface.material_override = _material
		# Dùng chung một material cho mỗi tuyến để đổi nhiệt bằng một lần cập nhật.
		for child: Node in surface.find_children("*", "MeshInstance3D", true, false):
			(child as MeshInstance3D).material_override = _material
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_timer.timeout.connect(_on_timeout)
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if heat != Heat.HOT:
		return
	for player: Player in _players:
		if is_instance_valid(player):
			failed.emit(player)


func configure(data: KhamPuzzleData) -> void:
	_data = data
	_material.set_shader_parameter(&"glow_strength", maxf(data.magma_glow_strength, 0.0))
	_material.set_shader_parameter(&"transition_color", data.hot_color)
	set_hot()


func cool_for(duration: float) -> void:
	var total: float = maxf(duration, 0.01)
	_warning_time = clampf(_data.heat_warning_time, 0.0, total * 0.9)
	_set_heat(Heat.COLD, _data.cold_color)
	_timer.start(maxf(total - _warning_time, 0.01))


func set_hot() -> void:
	_timer.stop()
	_set_heat(Heat.HOT, _data.hot_color)


func set_safe() -> void:
	_timer.stop()
	_set_heat(Heat.SAFE, _data.cold_color)


func has_player(player: Player) -> bool:
	return _players.has(player)


func _set_heat(value: Heat, color: Color) -> void:
	if _warning_tween != null:
		_warning_tween.kill()
	heat = value
	_material.set_shader_parameter(&"warning_progress", 0.0)
	_material.set_shader_parameter(&"surface_color", color)
	_material.set_shader_parameter(&"hot", value == Heat.HOT)
	_material.set_shader_parameter(&"warning", value == Heat.WARNING)
	if value == Heat.WARNING:
		# Một tween cho material dùng chung cả tuyến, không cập nhật từng ô mỗi frame.
		_warning_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		_warning_tween.tween_property(_material, ^"shader_parameter/warning_progress", 1.0, _warning_time)
	set_physics_process(value == Heat.HOT and not _players.is_empty())
	heat_changed.emit()


func _on_timeout() -> void:
	if heat == Heat.COLD and _warning_time > 0.0:
		_set_heat(Heat.WARNING, _data.cold_color)
		_timer.start(_warning_time)
	else:
		set_hot()


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or _players.has(player):
		return
	_players.append(player)
	set_physics_process(heat == Heat.HOT)


func _on_body_exited(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null:
		return
	_players.erase(player)
	set_physics_process(heat == Heat.HOT and not _players.is_empty())
