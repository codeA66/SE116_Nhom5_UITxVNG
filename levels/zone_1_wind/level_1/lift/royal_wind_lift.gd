extends Node3D
## Thang hoàng gia giữ tầng trên cho tới khi cáo rời hẳn bệ.

## Chỉ dùng làm tên tín hiệu chặn cắt cảnh tự chạy (cắt cảnh được gọi thẳng trong begin_trip); không phát thật
@warning_ignore("unused_signal")
signal trip_started
signal arrived

const CUTSCENE := preload("res://objects/world/camera_cutscene/camera_cutscene.tscn")
@export var travel_height: float = 4.22
@export var rise_time: float = 7.0
@export var return_time: float = 5.0
@export var boarding_radius: float = 1.25
@export var clear_radius: float = 3.15
@export var required_flag: StringName = &"level_1.enc_tower_fight"
@export var limestone_material: Material
@export var pale_stone_material: Material
@export var camera_data: CameraCutsceneData

var rider: Player
var candidate: Player
var elapsed: float = 0.0
var cinematic_finished: bool = false
var _cutscene: CameraCutscene

@onready var platform: AnimatableBody3D = $Platform
@onready var state_machine: StateMachine = $StateMachine
@onready var _bottom_gate: CollisionShape3D = $Gates/BottomGate
@onready var _top_gate: CollisionShape3D = $Gates/TopGate

func _ready() -> void:
	# Chỉ thay vật liệu của model tại bệ này để khớp ánh sáng cung điện.
	var limestone := $Platform/Model.find_child("Lift_CoolLimestone", true, false) as MeshInstance3D
	var pale_stone := $Platform/Model.find_child("Lift_PaleCutStone", true, false) as MeshInstance3D
	if limestone:
		limestone.material_override = limestone_material
	if pale_stone:
		pale_stone.material_override = pale_stone_material
	$Boarding.body_entered.connect(_on_entered)
	$Boarding.body_exited.connect(_on_exited)
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)

## State Docked gọi khi thang lên tới nơi: signal phát từ chính class khai báo nó
func notify_arrived() -> void:
	arrived.emit()

func is_docked() -> bool:
	return state_machine.current_state.name == &"Docked"

func get_platform_height() -> float:
	return platform.position.y

func set_gates(bottom_open: bool, top_open: bool) -> void:
	$Gates/BottomRail.visible = not bottom_open
	$Gates/TopRail.visible = not top_open
	_bottom_gate.set_deferred(&"disabled", bottom_open)
	_top_gate.set_deferred(&"disabled", top_open)

func begin_trip() -> void:
	$Platform/WindColumn.visible = true
	rider = candidate
	elapsed = 0.0
	cinematic_finished = false
	rider.health.died.connect(abort_trip, CONNECT_ONE_SHOT)
	_cutscene = CUTSCENE.instantiate() as CameraCutscene
	_cutscene.data = camera_data.duplicate() as CameraCutsceneData
	_cutscene.data.hold_time = maxf(rise_time, 0.1)
	_cutscene.focus_target = $Platform/Focus
	# Chặn trigger tự động; FSM gọi API kích hoạt sau khi scene sẵn sàng.
	_cutscene.trigger_source = self
	_cutscene.trigger_signal = &"trip_started"
	add_child(_cutscene)
	_cutscene.finished.connect(_on_cinematic_finished)
	(_cutscene.state_machine.current_state as CameraCutsceneState).on_player_entered(rider)

func release_trip() -> void:
	if is_instance_valid(rider) and rider.health.died.is_connected(abort_trip):
		rider.health.died.disconnect(abort_trip)
	if is_instance_valid(_cutscene):
		_cutscene.queue_free()
	_cutscene = null
	rider = null

func abort_trip() -> void:
	if is_instance_valid(_cutscene):
		_cutscene.end()
	release_trip()
	if is_inside_tree() and state_machine.current_state:
		state_machine.transition_to(&"Returning")

func _exit_tree() -> void:
	if is_instance_valid(_cutscene):
		_cutscene.end()
	release_trip()

func _on_cinematic_finished() -> void:
	cinematic_finished = true

func _on_entered(body: Node3D) -> void:
	if body is Player:
		candidate = body as Player
		set_physics_process(true)

func _on_exited(body: Node3D) -> void:
	if body == candidate:
		candidate = null
		if state_machine.current_state.name == &"Idle":
			set_physics_process(false)
