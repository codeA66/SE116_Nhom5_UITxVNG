extends Control
## Đếm số mục tiêu còn lại và số viên đạn bằng hai hàng biểu tượng.

class CounterIcon extends Control:
	var star := false
	var burst := -1.0:
		set(value):
			burst = value
			queue_redraw()
	var motion: Tween

	func _draw() -> void:
		var center := size * 0.5
		if burst >= 0.0:
			for index in 10:
				var angle := TAU * index / 10.0
				var point := center + Vector2.from_angle(angle) * (5.0 + burst * 27.0)
				point.y += 14.0 * burst * burst
				var color := Color("ffe461") if index % 2 == 0 else Color("ff9d45")
				color.a = 1.0 - burst
				draw_set_transform(point, angle + burst * 4.0)
				draw_rect(Rect2(-2, -1, 4, 2), color)
			return
		var outline := PackedVector2Array()
		if star:
			for index in 10:
				var radius := 13.0 if index % 2 == 0 else 6.0
				outline.append(center + Vector2.from_angle(-PI * 0.5 + index * TAU / 10.0) * radius)
		else:
			for point in [Vector2(-13, -7), Vector2(-8, 0), Vector2(0, 2), Vector2(8, -1), Vector2(12, -7), Vector2(13, -4), Vector2(11, 3), Vector2(5, 8), Vector2(-3, 9), Vector2(-10, 5), Vector2(-13, 0)]:
				outline.append(center + point)
		draw_colored_polygon(outline, Color("ffe563") if star else Color("ffd84d"))
		outline.append(outline[0])
		draw_polyline(outline, Color("694020"), 1.3, true)
		if not star:
			draw_arc(center + Vector2(0, -3), 9.0, 0.6, 2.7, 10, Color("fff4a9"), 1.5, true)

	func change(active: bool, delay: float) -> void:
		if motion:
			motion.kill()
		burst = -1.0
		show()
		scale = Vector2.ONE
		motion = create_tween()
		if active:
			scale = Vector2.ZERO
			motion.tween_property(self, "scale", Vector2.ONE, 0.35).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif star:
			motion.tween_property(self, "burst", 1.0, 0.45).from(0.0)
			motion.tween_callback(hide)
		else:
			motion.tween_property(self, "scale", Vector2.ZERO, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			motion.tween_callback(hide)

var _ammo: Array[CounterIcon]
var _stars: Array[CounterIcon]
var _last_ammo := -1
var _last_stars := -1

func setup(ammo_count: int, star_count: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_row(_stars, star_count, true)
	_make_row(_ammo, ammo_count, false)

func _make_row(row: Array[CounterIcon], count: int, stars: bool) -> void:
	for index in count:
		var icon := CounterIcon.new()
		icon.star = stars
		icon.size = Vector2(28, 30)
		icon.pivot_offset = icon.size * 0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position.x = -32.0 - (count - index) * 30.0 if stars else 32.0 + index * 30.0
		add_child(icon)
		row.append(icon)

func update_counts(ammo: int, remaining: int) -> void:
	_update_row(_ammo, _last_ammo, ammo)
	_update_row(_stars, _last_stars, remaining)
	_last_ammo = ammo
	_last_stars = remaining

func _update_row(row: Array[CounterIcon], old_count: int, count: int) -> void:
	for index in row.size():
		if (index < old_count) != (index < count):
			row[index].change(index < count, index * 0.035)
		elif old_count < 0:
			row[index].hide()
