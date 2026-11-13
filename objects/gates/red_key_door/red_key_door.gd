class_name RedKeyDoor
extends Node3D
## Cửa có ổ khóa liền thân: đúng chìa -> cắm chìa -> tan cửa -> mở lối.

signal opened
signal unlock_started
signal denied

## Model chìa đứng dọc theo trục Y: lật 90° quanh X cho thân chìa chĩa thẳng vào cửa,
## rồi xoay 90° quanh thân để răng chìa dựng đứng, khớp khe ổ khóa dọc lúc cắm vào
const DIALOG_SCENE: PackedScene = preload("res://ui/dialog/dialog_box.tscn")
const KEY_LAY_BASIS := Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI * 0.5)

@export var key_id: StringName
## Câu báo khi bấm tương tác mà chưa có chìa (map Lửa đặt câu này). Để trống = không báo gì, giữ hành vi cũ
## của các map khác (chỉ chớp đèn khóa); hộp thoại chỉ được tạo khi có câu
@export_multiline var locked_text: String = ""
@export var persistent_id: StringName
@export_range(0.1, 3.0, 0.05) var insert_time: float = 0.7
@export_range(0.2, 5.0, 0.1) var dissolve_time: float = 1.8
@export var dissolve_material: ShaderMaterial
## Vật liệu cho chìa cắm vào ổ (cửa màu khác dùng chung model chìa đỏ); để trống = giữ màu model
@export var key_material: Material
## Rung màn hình lúc cửa bắt đầu tan (0 = không rung)
@export_range(0.0, 1.0, 0.05) var open_trauma: float = 0.0

@export_group("Cắm chìa")
## Vị trí chìa lúc bắt đầu đưa vào và lúc đã cắm hết (đầu răng chìa nằm ở gốc model chìa)
@export var key_start_position: Vector3 = Vector3(0, 1.58, 1.28)
@export var key_end_position: Vector3 = Vector3(0, 1.58, 0.34)
## Góc vặn quanh thân chìa sau khi cắm
@export_range(-180.0, 180.0, 1.0) var key_twist_degrees: float = 90.0
## Mốc (phần thời gian cắm) bắt đầu vặn
@export_range(0.0, 1.0, 0.05) var key_twist_start: float = 0.6


var is_open: bool = false
var _dissolve: ShaderMaterial
var _deny_tween: Tween
# Người vừa bấm tương tác: hộp thoại cần biết để khóa điều khiển người đó lúc đang đọc
var _last_interactor: Player
var _dialog: DialogBox

@onready var state_machine: StateMachine = $StateMachine
@onready var interaction: InteractableComponent = $InteractableComponent
@onready var key_visual: Node3D = $InsertedKey
@onready var barrier: CollisionShape3D = $Barrier/CollisionShape3D
@onready var door_panels: MeshInstance3D = $Model.find_child("DoorPanels", true, false) as MeshInstance3D
@onready var lock_light: OmniLight3D = $LockLight

func _ready() -> void:
	if dissolve_material:
		_dissolve = dissolve_material.duplicate() as ShaderMaterial
		door_panels.material_override = _dissolve
	if key_material:
		for mesh: MeshInstance3D in key_visual.find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = key_material
	interaction.interacted.connect(_on_interacted)
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)

func has_key() -> bool:
	return not key_id.is_empty() and GameState.has_flag(key_id)

func was_opened() -> bool:
	return not persistent_id.is_empty() and GameState.has_flag(persistent_id)

func deny() -> void:
	denied.emit()
	if not locked_text.is_empty():
		_get_dialog().say(locked_text, _last_interactor)
	if _deny_tween:
		_deny_tween.kill()
	_deny_tween = create_tween()
	_deny_tween.tween_property(lock_light, "light_energy", 2.0, 0.08)
	_deny_tween.tween_property(lock_light, "light_energy", 0.6, 0.25)

## Tạo hộp thoại ở lần báo đầu: cửa không đặt locked_text thì không tốn node nào
func _get_dialog() -> DialogBox:
	if _dialog == null:
		_dialog = DIALOG_SCENE.instantiate() as DialogBox
		add_child(_dialog)
	return _dialog

func begin_insert() -> void:
	interaction.enabled = false
	key_visual.visible = true
	key_visual.position = key_start_position
	key_visual.basis = KEY_LAY_BASIS
	unlock_started.emit()

func update_insert(progress: float) -> void:
	var eased: float = smoothstep(0.0, 1.0, progress)
	key_visual.position = key_start_position.lerp(key_end_position, eased)
	# Vặn quanh chính thân chìa (trục Y của model): xoay tại chỗ trong ổ, không quét ngang ra ngoài
	var twist: float = deg_to_rad(key_twist_degrees) * smoothstep(key_twist_start, 1.0, progress)
	key_visual.basis = KEY_LAY_BASIS * Basis(Vector3.UP, twist)
	lock_light.light_energy = lerpf(0.6, 2.2, progress)

func begin_dissolve() -> void:
	key_visual.visible = false
	var motes: GPUParticles3D = get_node_or_null("DissolveMotes") as GPUParticles3D
	if motes:
		motes.restart()
	if open_trauma > 0.0:
		ScreenShake.add_trauma(open_trauma)

func update_dissolve(progress: float) -> void:
	if _dissolve:
		_dissolve.set_shader_parameter(&"dissolve", progress)
	lock_light.light_energy = lerpf(2.2, 0.0, progress)
	if progress >= 0.85:
		barrier.set_deferred(&"disabled", true)

func finish_open(remember: bool) -> void:
	is_open = true
	interaction.enabled = false
	key_visual.visible = false
	door_panels.visible = false
	barrier.set_deferred(&"disabled", true)
	lock_light.light_energy = 0.0
	set_physics_process(false)
	if remember:
		if not persistent_id.is_empty():
			GameState.set_flag(persistent_id)
		opened.emit()

func _on_interacted(interactor: Node3D) -> void:
	if interactor is Player:
		_last_interactor = interactor as Player
		(state_machine.current_state as RedKeyDoorState).interact()
