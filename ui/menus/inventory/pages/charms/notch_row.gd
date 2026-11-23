class_name NotchRow
extends Control
## Hiện sức chứa thật và phần dự kiến trên cùng hàng để người chơi thấy còn đeo được bao nhiêu.

const GLOW_SCALE: float = 1.6
const PREVIEW_INSET: float = 0.57

var used: float = 0.0
var total: int = 0

var _style: InventoryStyle
var _target_used: int = 0
var _preview_cost: int = 0
var _refusal: float = 0.0
var _fill_tween: Tween
var _refusal_tween: Tween


func configure(style: InventoryStyle) -> void:
	_style = style
	_update_minimum_size()
	queue_redraw()


func set_capacity(used_count: int, total_count: int, animate: bool) -> void:
	var capacity_changed: bool = total != total_count
	if _target_used == used_count and not capacity_changed:
		return
	if _fill_tween:
		_fill_tween.kill()
	total = total_count
	_target_used = used_count
	if capacity_changed:
		_update_minimum_size()
	var duration: float = absf(float(used_count) - used) * _style.notch_step_time
	if not animate or capacity_changed or duration <= 0.0:
		_set_used(float(used_count))
		return
	_fill_tween = create_tween()
	_fill_tween.tween_method(_set_used, used, float(used_count), duration)


func set_preview(cost: int) -> void:
	if _preview_cost == cost:
		return
	_preview_cost = cost
	queue_redraw()


func pulse_refusal() -> void:
	if _refusal_tween:
		_refusal_tween.kill()
	_refusal_tween = create_tween()
	_refusal_tween.tween_method(_set_refusal, 1.0, 0.0, _style.shake_time)


func _draw() -> void:
	if not _style or total <= 0 or total > clampi(_style.charm_notch_display_limit, 0, 24):
		return
	var requested: int = _target_used + _preview_cost
	var preview_color: Color = _style.warning if requested > total else _style.charm_preview_color
	var radius: float = _style.charm_notch_radius
	for index: int in range(total):
		var center: Vector2 = Vector2(_style.charm_notch_step * (float(index) + 0.5), size.y * 0.5)
		var fill: float = clampf(used - float(index), 0.0, 1.0)
		var is_preview: bool = index >= _target_used and index < requested
		var rim: Color = preview_color if is_preview else _style.charm_socket_edge
		rim = rim.lerp(_style.warning, _refusal)
		_draw_notch(center, radius, rim)
		if fill > 0.0:
			var light: Color = _style.charm_preview_color.lerp(_style.warning, _refusal)
			draw_circle(center, radius * GLOW_SCALE, Color(light, 0.13 * fill), true, -1.0, true)
			_draw_notch(center, radius * lerpf(0.45, 0.82, fill), Color(light, fill))
			draw_line(center - Vector2(0.0, radius * fill * 0.6), center + Vector2(0.0, radius * fill * 0.6), Color(light, fill), radius * 0.6, true)
		elif is_preview:
			_draw_notch(center, radius * PREVIEW_INSET, preview_color)


func _draw_notch(center: Vector2, radius: float, color: Color) -> void:
	var top: Vector2 = center - Vector2(0.0, radius)
	var right: Vector2 = center + Vector2(radius * 0.72, 0.0)
	var bottom: Vector2 = center + Vector2(0.0, radius)
	var left: Vector2 = center - Vector2(radius * 0.72, 0.0)
	draw_line(top, right, color, _style.charm_border_width, true)
	draw_line(right, bottom, color, _style.charm_border_width, true)
	draw_line(bottom, left, color, _style.charm_border_width, true)
	draw_line(left, top, color, _style.charm_border_width, true)


func _update_minimum_size() -> void:
	var visible_count: int = total if total <= clampi(_style.charm_notch_display_limit, 0, 24) else 0
	custom_minimum_size = Vector2(_style.charm_notch_step * float(visible_count),
		_style.charm_notch_radius * 2.0 * GLOW_SCALE)


func _set_used(value: float) -> void:
	used = value
	queue_redraw()


func _set_refusal(value: float) -> void:
	_refusal = value
	queue_redraw()
