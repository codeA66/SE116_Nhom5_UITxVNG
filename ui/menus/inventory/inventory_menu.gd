class_name InventoryMenu
extends PanelContainer
## Tủ đồ: ghép / tháo / chuyển nguyên tố giữa các vũ khí bằng kéo thả chuột. Bảng nằm một bên màn hình,
## game KHÔNG dừng (quái vẫn đánh). Đang mở thì Player bỏ qua nút đánh (chuột trái cũng là nút đánh).
## Chỉ dựng lại các ô khi đang mở và tiến trình đổi; không chạy mỗi frame.

signal opened
signal closed

const HINT := "Kéo nguyên tố vào vũ khí để ghép, kéo ra hoặc chuột phải để tháo.\nNguyên tố đang ghép thì kỹ năng gốc tạm khóa."

@export var player: Player
@export var toggle_action: StringName = &"inventory"

@onready var _elements: HBoxContainer = %Elements
@onready var _weapons: VBoxContainer = %Weapons
@onready var _info: Label = %Info


func _ready() -> void:
	visible = false
	set_process(false)
	GameState.fusion_changed.connect(_refresh_if_open)
	GameState.progress_changed.connect(_refresh_if_open)
	GameState.progress_replaced.connect(_refresh_if_open)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(toggle_action):
		return
	get_viewport().set_input_as_handled()
	if visible:
		close()
	elif player == null or player.controls_enabled:
		open()


func open() -> void:
	visible = true
	_info.text = HINT
	_refresh()
	if player:
		player.set_attack_blocked_by_ui(true)
	opened.emit()


func close() -> void:
	visible = false
	if player:
		player.set_attack_blocked_by_ui(false)
	closed.emit()


## Ô kéo thả: chấm màu nguyên tố bám theo con trỏ
static func make_drag_preview(element: ElementData) -> Control:
	var dot := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = element.color
	style.set_corner_radius_all(18)
	dot.add_theme_stylebox_override(&"panel", style)
	dot.size = Vector2(36, 36)
	dot.position = -dot.size * 0.5
	var holder := Control.new()
	holder.add_child(dot)
	return holder


func _refresh_if_open() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	var fused_at := {}
	for slot: int in GameState.progress.fusions:
		fused_at[GameState.progress.fusions[slot]] = slot
	var owned := GameState.get_owned_elements()
	var elements := GameState.FUSIONS.elements
	_resize(_elements, elements.size(), ElementSlot)
	for i in elements.size():
		var element := elements[i]
		(_elements.get_child(i) as ElementSlot).setup(element, owned.has(element), fused_at.get(element.id, -1))
	var weapons := GameState.progress.weapons
	_resize(_weapons, weapons.size(), WeaponFusionSlot)
	for i in weapons.size():
		var weapon := weapons[i]
		var element := GameState.get_fused_element(weapon.slot)
		var fusion := GameState.FUSIONS.get_fusion(weapon.slot, element.id) if element else null
		(_weapons.get_child(i) as WeaponFusionSlot).setup(weapon, element, fusion)


## Giữ đúng số ô cần (tạo mới / bỏ bớt), không dựng lại từ đầu mỗi lần làm mới
func _resize(container: Container, count: int, kind: GDScript) -> void:
	while container.get_child_count() < count:
		var slot: Control = kind.new()
		slot.hovered.connect(_on_slot_hovered)
		container.add_child(slot)
	while container.get_child_count() > count:
		var extra := container.get_child(container.get_child_count() - 1)
		container.remove_child(extra)
		extra.queue_free()


func _on_slot_hovered(text: String) -> void:
	_info.text = text
