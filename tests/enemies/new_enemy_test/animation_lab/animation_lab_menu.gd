class_name EnemyLabMenu
extends CanvasLayer
## Chọn quái khi tạm dừng, hoặc đổi clip ngay trên thanh xem animation.

signal shortcut_input(event: InputEvent)
signal spawn_selected(scene: PackedScene)
signal clear_selected
signal clip_selected(clip: StringName)
signal move_selected(id: StringName, title: String)
signal preview_pause_requested
signal ai_changed(enabled: bool)
signal dismissed
signal animation_hovered(inside: bool)

const MENU_THEME := preload("res://ui/theme/menu_theme.tres")

var _hint: Label
var _catalog: Control
var _cards: GridContainer
var _previews: Array[SubViewport]
var _bar: PanelContainer
var _current: Label
var _clips: OptionButton
var _moves: OptionButton
var _pause: Button
var _ai_off: Button
var _ai_on: Button
var _enemy_label: String
var _has_enemy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build_catalog()
	_build_clip_bar()
	_hint = Label.new()
	_hint.theme = MENU_THEME
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.text = "I  Chọn quái   ·   O  Animation"
	_hint.position = Vector2(22.0, 18.0)
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_hint.offset_left = -268
	_hint.offset_right = -22
	_hint.offset_top = 20
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	set_in_room(false)


func _input(event: InputEvent) -> void:
	shortcut_input.emit(event)


func set_in_room(value: bool) -> void:
	_hint.visible = value
	if not value:
		hide_catalog()
		hide_clips()


func show_catalog(roster: Array[PackedScene]) -> void:
	if _cards.get_child_count() == 0:
		for scene: PackedScene in roster:
			_add_enemy_card(scene)
		var clear := _button("Dọn phòng")
		clear.custom_minimum_size = Vector2(172.0, 124.0)
		clear.pressed.connect(func() -> void: clear_selected.emit())
		_cards.add_child(clear)
	_catalog.show()
	for preview: SubViewport in _previews:
		preview.render_target_update_mode = SubViewport.UPDATE_ONCE


func hide_catalog() -> void:
	_catalog.hide()


func toggle_clips() -> void:
	if _bar.visible:
		hide_clips()
	else:
		_bar.show()


func hide_clips() -> void:
	if _bar.visible:
		_bar.hide()
		animation_hovered.emit(false)


func set_enemy(enemy_name: String, clips: PackedStringArray) -> void:
	_enemy_label = enemy_name
	_has_enemy = not enemy_name.is_empty()
	_clips.clear()
	_clips.add_item("Chọn animation")
	clips.sort()
	for clip: String in clips:
		if clip != "RESET":
			_clips.add_item(clip)
	set_playing(&"")
	_moves.clear()
	_moves.add_item("Chiêu thức")
	set_ai(false)


func set_ai(enabled: bool, corpse: bool = false) -> void:
	_ai_off.set_pressed_no_signal(not enabled)
	_ai_on.set_pressed_no_signal(enabled)
	_ai_off.disabled = not _has_enemy or corpse
	_ai_on.disabled = not _has_enemy or corpse
	_clips.disabled = not _has_enemy or enabled
	_moves.visible = _moves.item_count > 1
	_moves.disabled = enabled or not _has_enemy


func set_elephant_moves(skills: Array[EnemySkillData]) -> void:
	for skill: EnemySkillData in skills:
		var move := skill as ElephantSkill
		add_move(move.skill_id, move.title)
	add_move(&"introduction", "Mở màn · Camera")


func add_move(id: StringName, title: String) -> void:
	_moves.add_item(title)
	_moves.set_item_metadata(_moves.item_count - 1, id)
	_moves.show()


func set_preview_pause(available: bool, paused: bool = false) -> void:
	_pause.disabled = not available
	_pause.text = "Tiếp tục" if paused else "Dừng frame"


func set_playing(clip: StringName) -> void:
	_current.text = "Chưa có quái" if not _has_enemy else _enemy_label
	if not clip.is_empty():
		_current.text += " · " + String(clip)


func _build_catalog() -> void:
	_catalog = Control.new()
	add_child(_catalog)
	_catalog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.035, 0.77)
	_catalog.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_catalog.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.theme = MENU_THEME
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var title := Label.new()
	title.text = "Chọn quái"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button("Đóng [I]")
	close.pressed.connect(func() -> void: dismissed.emit())
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740.0, 392.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	_cards = GridContainer.new()
	_cards.columns = 4
	_cards.add_theme_constant_override("h_separation", 10)
	_cards.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_cards)
	_catalog.hide()


func _build_clip_bar() -> void:
	_bar = PanelContainer.new()
	_bar.theme = MENU_THEME
	_bar.add_theme_stylebox_override("panel", _panel_style())
	add_child(_bar)
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = -396.0
	_bar.offset_right = 396.0
	_bar.offset_top = -112.0
	_bar.offset_bottom = -40.0
	_bar.mouse_entered.connect(func() -> void: animation_hovered.emit(true))
	_bar.mouse_exited.connect(func() -> void: animation_hovered.emit(false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_bar.add_child(row)
	var label_box := VBoxContainer.new()
	label_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label_box)
	_current = Label.new()
	_current.clip_text = true
	_current.add_theme_font_size_override("font_size", 17)
	label_box.add_child(_current)
	_clips = _make_picker(205.0)
	_clips.item_selected.connect(_on_clip_selected)
	label_box.add_child(_clips)
	_moves = _make_picker(115.0)
	_moves.item_selected.connect(_on_move_selected)
	row.add_child(_moves)
	_pause = _button("Dừng frame")
	_pause.pressed.connect(func() -> void: preview_pause_requested.emit())
	_pause.disabled = true
	row.add_child(_pause)
	var group := ButtonGroup.new()
	_ai_off = _button("Tắt AI")
	_ai_on = _button("Bật AI")
	for button: Button in [_ai_off, _ai_on]:
		button.toggle_mode = true
		button.button_group = group
		row.add_child(button)
	_ai_off.pressed.connect(func() -> void: ai_changed.emit(false))
	_ai_on.pressed.connect(func() -> void: ai_changed.emit(true))
	var close := _button("Đóng [O]")
	close.pressed.connect(hide_clips)
	row.add_child(close)
	set_enemy("", PackedStringArray())
	_bar.hide()


func _on_clip_selected(index: int) -> void:
	if index > 0:
		clip_selected.emit(StringName(_clips.get_item_text(index)))
	_clips.select(0)


func _on_move_selected(index: int) -> void:
	if index > 0:
		move_selected.emit(_moves.get_item_metadata(index), _moves.get_item_text(index))
	_moves.select(0)


func _make_picker(width: float) -> OptionButton:
	var picker := OptionButton.new()
	picker.fit_to_longest_item = false
	picker.custom_minimum_size = Vector2(width, 30.0)
	picker.add_theme_font_size_override("font_size", 15)
	var popup := picker.get_popup()
	popup.max_size = Vector2i(460, 360)
	popup.add_theme_font_size_override("font_size", 16)
	popup.about_to_popup.connect(func() -> void: animation_hovered.emit(true))
	popup.popup_hide.connect(func() -> void: animation_hovered.emit(_bar.get_global_rect().has_point(_bar.get_global_mouse_position())))
	return picker


func _add_enemy_card(scene: PackedScene) -> void:
	var ghost := scene.instantiate() as Enemy
	var visual := ghost.get_node("Model").duplicate(0) as Node3D
	var button := _button("")
	button.custom_minimum_size = Vector2(172.0, 124.0)
	button.pressed.connect(func() -> void: spawn_selected.emit(scene))
	_cards.add_child(button)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := SubViewportContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.stretch = true
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(frame)
	var preview := SubViewport.new()
	preview.own_world_3d = true
	preview.transparent_bg = true
	preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	preview.gui_disable_input = true
	_previews.append(preview)
	frame.add_child(preview)
	var display_root := Node3D.new()
	display_root.name = &"Model"
	preview.add_child(display_root)
	display_root.add_child(visual)
	var animator: AnimationPlayer
	if ghost is PreviewFireBoss:
		animator = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	else:
		animator = ghost.get_node("AnimationPlayer").duplicate(0) as AnimationPlayer
		display_root.add_child(animator)
	var config := ghost.data as WildEnemyData
	if config and animator and animator.has_animation(config.idle_animation):
		animator.play(config.idle_animation)
		animator.advance(0.0)
		animator.pause()
	var bounds := _visual_bounds(visual, ghost)
	var light := DirectionalLight3D.new()
	preview.add_child(light)
	light.rotation_degrees = Vector3(-37, 142, 0)
	light.light_energy = 0.9
	var fill := DirectionalLight3D.new()
	preview.add_child(fill)
	fill.rotation_degrees = Vector3(-28, -40, 0)
	fill.light_energy = 0.35
	var camera := Camera3D.new()
	preview.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(bounds.size.y, bounds.size.length() * 0.65) * 1.17
	var focus := bounds.get_center()
	camera.look_at_from_position(focus + Vector3(5, 3.4, 8), focus)
	camera.make_current()
	var label := Label.new()
	label.text = ghost.data.display_name
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(label)
	ghost.free()


func _visual_bounds(visual: Node3D, ghost: Enemy) -> AABB:
	var collision := ghost.get_node("CollisionShape3D") as CollisionShape3D
	var body_size := collision.shape.get_debug_mesh().get_aabb().size
	var body := AABB(collision.position - body_size * 0.5, body_size)
	var bounds := AABB()
	for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		# Một số rig lưu mesh ở tỉ lệ rất nhỏ rồi mới áp skin khi render.
		if mesh.skin and box.size.length() < body_size.length() * 0.1:
			var posed := mesh.bake_mesh_from_current_skeleton_pose()
			if posed:
				box = mesh.global_transform * posed.get_aabb()
		bounds = bounds.merge(box) if bounds.has_volume() else box
	# Các rig cũ có AABB bind pose lớn hơn pose trong game.
	if not bounds.has_volume() or bounds.size.length() > body_size.length() * 3.7 or not bounds.intersects(body):
		return body.grow(0.32)
	return bounds


func _button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _panel_style(Color("202c35")))
	button.add_theme_stylebox_override("hover", _panel_style(Color("304554")))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("4d4936")))
	return button


func _panel_style(background: Color = Color("151b23")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color("867854")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style
