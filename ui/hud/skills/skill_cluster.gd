@tool
class_name SkillCluster
extends Control
## Cụm ô nối state/cooldown bằng signal; thêm ô bằng node + dữ liệu glyph/anchor.
const Slot = preload("res://ui/hud/skills/slots/skill_slot.gd")
const Style = preload("res://resources/ui/hud_style.gd")
@export var player_path: NodePath
@export var style: Style = preload("res://resources/ui/hud_style.tres")
var _slots: Array[Slot] = []
var _panel_outline: PackedVector2Array = PackedVector2Array()
var _panel_height: float = 0.0
var _divider_x: float = NAN
@onready var _binding_refresh: Timer = $BindingRefresh
## Cache con trực tiếp một lần; đợi Player.ready trước khi lấy state_machine.
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)
	for child: Node in get_children():
		if child is Slot: _slots.append(child as Slot)
	apply_style()
	if Engine.is_editor_hint(): return
	GameState.progress_changed.connect(_refresh)
	GameState.progress_replaced.connect(_refresh)
	GameState.fusion_changed.connect(_refresh)
	GameState.ability_unlocked.connect(_on_ability_unlocked)
	_binding_refresh.timeout.connect(_refresh_bindings)
	_connect_player()
	_refresh()
## Giữ các node name/path đang được VFX nhận kỹ năng và test sử dụng.
func apply_style() -> void:
	var radius: float = style.get_skill_radius()
	var step: float = style.get_skill_step()
	var min_anchor: Vector2 = Vector2.ZERO
	var max_anchor: Vector2 = Vector2.ZERO
	for slot_node: Slot in _slots:
		var anchor: Vector2 = style.skill_anchors.get(slot_node.glyph_id, Vector2.ZERO)
		min_anchor = min_anchor.min(anchor)
		max_anchor = max_anchor.max(anchor)
	var edge: float = radius + style.stroke_width()
	var bottom: float = edge
	if style.skill_show_key_badges:
		var badge_bottom: float = style.skill_badge_anchor.y * radius + clampf(style.skill_badge_height, 1, 64) * 0.5
		bottom = maxf(bottom, badge_bottom * style.get_active_scale() + style.stroke_width())
	var first_center: Vector2 = Vector2.ONE * edge - min_anchor * step
	custom_minimum_size = (max_anchor - min_anchor) * step + Vector2(edge * 2, edge + bottom)
	size = custom_minimum_size
	var width: float = custom_minimum_size.x
	_panel_height = (max_anchor.y - min_anchor.y) * step + edge * 2.0
	var bevel: float = radius * 0.35
	_panel_outline = PackedVector2Array([Vector2.ZERO, Vector2(width-bevel,0), Vector2(width,bevel),
		Vector2(width,_panel_height), Vector2(bevel,_panel_height), Vector2(0,_panel_height-bevel), Vector2.ZERO])
	_divider_x = NAN
	if style.skill_divider_column > min_anchor.x and style.skill_divider_column < max_anchor.x:
		_divider_x = first_center.x + style.skill_divider_column * step
	queue_redraw()
	for slot_node: Slot in _slots:
		slot_node.style = style
		slot_node.apply_style()
		var anchor: Vector2 = style.skill_anchors.get(slot_node.glyph_id,Vector2.ZERO)
		slot_node.position = first_center + anchor * step - slot_node.size * 0.5
## Một nền chung để các dấu hồi chiêu và trang bị nổi hơn viền từng ô.
func _draw() -> void:
	if not style.skill_shared_panel or _panel_outline.size() < 3: return
	var line: float = style.stroke_width()
	draw_colored_polygon(_panel_outline,style.skill_fill)
	draw_polyline(_panel_outline,style.ink,line,true)
	draw_line(_panel_outline[0]+Vector2.ONE*line,_panel_outline[1]+Vector2.DOWN*line,Color(style.gold,0.35),line,true)
	if is_finite(_divider_x):
		var inset: float = style.get_skill_radius() * 0.45
		draw_line(Vector2(_divider_x,inset),Vector2(_divider_x,_panel_height-inset),Color(style.gold,0.40),line,true)
## Không đọc onready của chủ sở hữu khi chính HUD vẫn đang ready trước chủ.
func _connect_player() -> void:
	if player_path.is_empty(): return
	var player: Node = get_node_or_null(player_path)
	if player == null: return
	for slot_node: Slot in _slots:
		if slot_node.cooldown_signal.is_empty():
			if slot_node.has_method(&"on_skill_cooldown") and player.has_signal(&"skill_cooldown_started"):
				player.connect(&"skill_cooldown_started",Callable(slot_node,&"on_skill_cooldown"))
		elif player.has_signal(slot_node.cooldown_signal):
			player.connect(slot_node.cooldown_signal,slot_node.start_cooldown)
	if not player.is_node_ready(): await player.ready
	if not is_instance_valid(player) or not is_inside_tree(): return
	var state_machine: StateMachine = player.get(&"state_machine") as StateMachine
	if state_machine != null: state_machine.state_changed.connect(_on_player_state_changed)
## Cập nhật theo chuyển trạng thái, không so state.name từng frame.
func _on_player_state_changed(_from: StringName, to: StringName) -> void:
	for slot_node: Slot in _slots: slot_node.set_active(to in slot_node.active_states)
## Những signal không có payload dùng cùng đường refresh.
func _refresh() -> void:
	for slot_node: Slot in _slots: slot_node.refresh()
## Adapter bỏ payload của signal mở khóa mà không đổi kiến trúc hiện có.
func _on_ability_unlocked(_ability: AbilityData) -> void:
	_refresh()
## InputMap không có signal đổi binding; giữ timer sẵn có, không thêm polling mỗi frame.
func _refresh_bindings() -> void:
	if is_visible_in_tree():
		for slot_node: Slot in _slots: slot_node.refresh_binding()
