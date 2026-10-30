class_name InteractionPrompt
extends PanelContainer
## Gợi ý tương tác dạng "[E] PICK UP": UI 2D bám theo vị trí 3D của vật đang được chọn.
## Luôn sắc nét và giữ nguyên kích thước dù camera xa hay gần.

@export var interactor: InteractorComponent
## Action trong Input Map, chữ phím được đọc từ đây thay vì ghi cứng
@export var action: StringName = &"interact"
## Lệch so với điểm chiếu trên màn hình (pixel), dương = xuống dưới
@export var screen_offset: Vector2 = Vector2(0.0, 28.0)

var _target: InteractableComponent

@onready var _key_label: Label = %KeyLabel
@onready var _action_label: Label = %ActionLabel


func _ready() -> void:
	hide()
	_key_label.text = _get_key_text()
	if interactor:
		interactor.focus_changed.connect(_on_focus_changed)


func _process(_delta: float) -> void:
	if not is_instance_valid(_target) or not _target.enabled:
		hide()
		return
	var camera := get_viewport().get_camera_3d()
	var world_position := _target.get_prompt_position()
	if camera == null or camera.is_position_behind(world_position):
		hide()
		return
	show()
	# Căn giữa theo chiều ngang quanh điểm chiếu
	position = camera.unproject_position(world_position) + screen_offset - Vector2(size.x * 0.5, 0.0)


func _on_focus_changed(target: InteractableComponent) -> void:
	_target = target
	if target:
		_action_label.text = target.prompt_text.to_upper()
		reset_size()


func _get_key_text() -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return OS.get_keycode_string(code)
	return "?"
