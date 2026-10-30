@tool
class_name SkillCluster
extends Control
## Cụm ô kỹ năng: các SkillSlot con trực tiếp; thêm kỹ năng mới = thêm node ô, không sửa file này.
## Ô chưa có vẫn vẽ rỗng nên bố cục cụm không đổi khi nhặt thêm.
## Hồi chiêu nối theo SkillSlot.cooldown_signal, ô nổi lên theo SkillSlot.active_states; đều qua signal, không dò mỗi frame.

## Player phát các signal hồi chiêu và có state_machine; để trống thì ô không hồi chiêu / không nổi lên
@export var player_path: NodePath

var _slots: Array[SkillSlot] = []

@onready var _binding_refresh: Timer = $BindingRefresh


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for child in get_children():
		if child is SkillSlot:
			_slots.append(child)
	if Engine.is_editor_hint():
		return
	GameState.progress_changed.connect(_refresh)
	GameState.progress_replaced.connect(_refresh)
	GameState.ability_unlocked.connect(_on_ability_unlocked)
	_binding_refresh.timeout.connect(_refresh_bindings)
	_connect_player()
	_refresh()


func _connect_player() -> void:
	var player := get_node_or_null(player_path)
	if player == null:
		return
	for slot in _slots:
		if slot.cooldown_signal.is_empty():
			# Ô kỹ năng không đặt signal riêng: nghe signal chung của mọi kỹ năng, ô tự lọc theo id
			if slot.has_method(&"on_skill_cooldown") and player.has_signal(&"skill_cooldown_started"):
				player.connect(&"skill_cooldown_started", Callable(slot, &"on_skill_cooldown"))
			continue
		if player.has_signal(slot.cooldown_signal):
			player.connect(slot.cooldown_signal, slot.start_cooldown)
		else:
			push_warning("%s: player không có signal %s" % [slot.name, slot.cooldown_signal])
	# Ô nổi lên đúng lúc player ở state của chiêu đó (đang chém, đang nhắm, đang dùng gió...).
	# HUD là con của player nên _ready chạy trước: chờ player gán xong @onready state_machine
	if not player.is_node_ready():
		await player.ready
	var state_machine := player.get(&"state_machine") as StateMachine
	if state_machine:
		state_machine.state_changed.connect(_on_player_state_changed)


func _on_player_state_changed(_from: StringName, to: StringName) -> void:
	for slot in _slots:
		slot.set_active(to in slot.active_states)


func _refresh() -> void:
	for slot in _slots:
		slot.refresh()


func _on_ability_unlocked(_ability: AbilityData) -> void:
	_refresh()


func _refresh_bindings() -> void:
	# InputMap không phát signal khi action_add_event/action_erase_events được gọi.
	# Chỉ kiểm tra 4 lần/giây khi HUD đang hiện, không dựng lại ô mỗi frame.
	if is_visible_in_tree():
		for slot in _slots:
			slot.refresh_binding()
