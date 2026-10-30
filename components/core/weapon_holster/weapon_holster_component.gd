class_name WeaponHolsterComponent
extends Node
## Cất vũ khí vào chỗ đeo (hông, lưng...) khi không đánh, rút về tay khi vào state đánh.
## Chỉ chuyển cha của đúng mesh vũ khí có sẵn (reparent), không tạo bản sao.
## Hiệu năng: nghe StateMachine.state_changed, không chạy _process.

## Vũ khí vừa rút ra tay (true) hoặc vừa cất vào chỗ đeo (false); player dùng để đổi clip đứng/chạy
signal drawn_changed(drawn: bool)

@export var state_machine: StateMachine
@export var skeleton: Skeleton3D
## Mesh vũ khí đang gắn ở tay (vị trí trên tay lấy đúng như lúc vào scene)
@export var weapon: Node3D
## Xương gắn vũ khí khi cất (hông, lưng...)
@export var holster_bone: StringName = &"hips"
## Vị trí / góc / tỉ lệ vũ khí so với xương đeo (chỉnh trong Inspector cho vừa model)
@export var holster_transform: Transform3D = Transform3D.IDENTITY
## Vào một trong các state này thì rút vũ khí
@export var draw_states: Array[StringName] = [&"Attack"]
## Rời state đánh bao lâu thì cất (giây). 0 = cất ngay khi hết đòn
@export_range(0.0, 10.0, 0.05, "or_greater") var sheathe_delay: float = 0.0

var drawn: bool = true

var _hand_parent: Node
var _hand_transform: Transform3D
var _holster_mount: Node3D
var _sheathe_timer: Timer


func _ready() -> void:
	if state_machine == null or skeleton == null or weapon == null:
		push_warning("%s: chưa gán state_machine / skeleton / weapon" % get_path())
		return
	_hand_parent = weapon.get_parent()
	_hand_transform = weapon.transform
	# Tạo một lần: BoneAttachment3D theo xương đeo + node con mang holster_transform
	var attachment := BoneAttachment3D.new()
	attachment.name = &"WeaponHolsterAttachment"
	attachment.bone_name = holster_bone
	skeleton.add_child(attachment)
	_holster_mount = Node3D.new()
	_holster_mount.name = &"HolsterMount"
	attachment.add_child(_holster_mount)
	_sheathe_timer = Timer.new()
	_sheathe_timer.one_shot = true
	_sheathe_timer.timeout.connect(_set_drawn.bind(false))
	add_child(_sheathe_timer)
	state_machine.state_changed.connect(_on_state_changed)
	_set_drawn(false)


func _on_state_changed(_from: StringName, to: StringName) -> void:
	if to in draw_states:
		_sheathe_timer.stop()
		_set_drawn(true)
	elif drawn:
		if sheathe_delay <= 0.0:
			_set_drawn(false)
		elif _sheathe_timer.is_stopped():
			_sheathe_timer.start(sheathe_delay)


func _set_drawn(value: bool) -> void:
	if drawn == value:
		return
	drawn = value
	if drawn:
		weapon.reparent(_hand_parent, false)
		weapon.transform = _hand_transform
	else:
		weapon.reparent(_holster_mount, false)
		weapon.transform = holster_transform
	drawn_changed.emit(drawn)
