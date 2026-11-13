@tool
class_name HealthSegment
extends Control
## Đầu cáo có mõm/tai riêng: ô mất vẫn đọc được đường bao; mảnh vỡ tái dùng dữ liệu.
const Style = preload("res://resources/ui/hud_style.gd")
@export var style: Style = preload("res://resources/ui/hud_style.tres")
const REFILL_DURATION: float = 0.52
var filled: bool = true
var _age: float = INF
var _refill_age: float = INF
var _low: bool = false
var _clock: float = 0.0
var _animating: bool = false
var _head: PackedVector2Array = PackedVector2Array()
var _outline: PackedVector2Array = PackedVector2Array()
var _nose: PackedVector2Array = PackedVector2Array([Vector2(-0.13,0.43),Vector2(0.13,0.43),Vector2(0,0.64)])
var _crack: PackedVector2Array = PackedVector2Array([Vector2(0.08,-0.5),Vector2(-0.13,-0.1),Vector2(0.16,0.13),Vector2(-0.12,0.65)])
var _shards: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(-0.85,-0.95),Vector2(-0.18,-0.54),Vector2(-0.69,-0.04)]),
	PackedVector2Array([Vector2(0.18,-0.54),Vector2(0.85,-0.95),Vector2(0.69,-0.04)]),
	PackedVector2Array([Vector2(-0.94,0.21),Vector2(-0.44,0.65),Vector2(-0.15,0.12)]),
	PackedVector2Array([Vector2(0.94,0.21),Vector2(0.44,0.65),Vector2(0.15,0.12)])]
## Cache đường bao một lần; thay style/resize không cấp phát trong lượt vỡ.
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	apply_style()
	set_process(false)
## Dữ liệu glyph có thể thay bằng tranh tay mà không sửa HealthBar.
func apply_style() -> void:
	var glyph: Resource = style.glyphs.get(&"health")
	if glyph != null and not glyph.fills.is_empty() and glyph.fills[0].size()>=3:
		_head = glyph.fills[0].duplicate()
		_outline = _head.duplicate()
		_outline.append(_head[0])
	else:
		_head = PackedVector2Array()
		_outline = PackedVector2Array()
	custom_minimum_size = Vector2(maxf(style.health_icon_size.x,1),maxf(style.health_icon_size.y,1))
	queue_redraw()
## API cũ được giữ: refresh không khởi động lại hiệu ứng nếu trạng thái không đổi.
func set_filled(value: bool, animate: bool = true, refill_delay: float = 0.0) -> void:
	if filled == value: return
	filled = value
	_age = 0.0 if animate else INF
	_refill_age = -refill_delay if filled and animate else INF
	_animating = animate
	set_process(_animating or _low)
	queue_redraw()
## Chỉ đầu cáo cuối còn sống nhịp khi nguy cấp; hồi máu tắt process ngay sau đuôi hiệu ứng.
func set_low_health(value: bool) -> void:
	if _low == value: return
	_low = value
	_clock = 0.0
	set_process(_animating or _low)
	queue_redraw()
## Nhịp liên tục chỉ dành cho cảnh báo có chủ ý; các mảnh vỡ có thời hạn cố định.
func _process(delta: float) -> void:
	_age += delta
	_refill_age += delta
	_clock += delta
	_animating = _age < maxf(style.health_transition_time,style.health_shard_time) or _refill_age < REFILL_DURATION
	queue_redraw()
	if not _animating and not _low: set_process(false)
## Render chỉ đọc các mảng có sẵn; không spawn particle/node khi bị đánh liên tục.
func _draw() -> void:
	if style == null: return
	var art: Texture2D = style.health_full_texture if filled else style.health_empty_texture
	if _head.is_empty() and art == null: return
	var extent: float = maxf(minf(size.x,size.y)*0.43,0.01)
	var center: Vector2 = size*0.5
	var t: float = clampf(_age/maxf(style.health_transition_time,0.001),0,1)
	var pulse: float = clampf(style.health_pulse_amount,0.0,1.0)*(0.5+0.5*sin(_clock*style.health_pulse_speed)) if _low else 0.0
	var fill_color: Color = style.health_empty_fill.lerp(style.ivory,t) if filled else style.ivory.lerp(style.health_empty_fill,t)
	if filled and _animating: fill_color = fill_color.lerp(style.heal_color,(1.0-t)*0.6)
	if filled: fill_color = fill_color.lerp(style.heal_color,pulse)
	var refill: float = clampf(_refill_age / REFILL_DURATION, 0.0, 1.0)
	var reveal: float = smoothstep(0.28, 0.37, refill)
	var flash: float = smoothstep(0.24, 0.34, refill) * (1.0 - smoothstep(0.39, 0.74, refill))
	if art != null:
		if refill < 1.0 and style.health_empty_texture != null:
			draw_texture_rect(style.health_empty_texture, Rect2(Vector2.ZERO, size), false,
				Color(1.0, 1.0, 1.0, 1.0 - reveal))
		var art_size: Vector2 = size * (1.0 + flash * 0.16)
		draw_texture_rect(art,Rect2((size - art_size) * 0.5,art_size),false,
			Color(Color.WHITE.lerp(style.heal_color, maxf(pulse, flash)), reveal))
	else:
		draw_set_transform(center,0,Vector2.ONE * extent * (1.0 + flash * 0.20))
		draw_polyline(_outline,style.ink,(style.stroke_width()+clampf(style.health_shadow_width,0,4))/extent,true)
		draw_colored_polygon(_head, fill_color if refill >= 1.0 else style.health_empty_fill.lerp(style.ivory, reveal).lerp(style.heal_color, flash))
		var rim: Color = style.muted.lerp(style.gold, reveal) if filled else style.muted
		draw_polyline(_outline,rim,style.stroke_width()/extent,true)
		if filled or t < 1.0:
			var details: Color = Color(style.ink, reveal)
			draw_line(Vector2(-0.56,-0.09),Vector2(-0.22,0.12),details,style.stroke_width()/extent,true)
			draw_line(Vector2(0.56,-0.09),Vector2(0.22,0.12),details,style.stroke_width()/extent,true)
			draw_colored_polygon(_nose,details)
		if not filled and _age < style.health_crack_time:
			draw_polyline(_crack,style.damage_color,style.stroke_width()*1.5/extent,true)
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if refill < 1.0:
		_draw_refill(center, extent, refill, flash)
	if not filled and _age < style.health_shard_time:
		var life: float = clampf(_age/maxf(style.health_shard_time,0.001),0,1)
		for index: int in range(clampi(style.health_shard_count,0,_shards.size())):
			var angle: float = float(index)*TAU/float(_shards.size())-PI*0.75
			var offset: Vector2 = Vector2(cos(angle),sin(angle))*style.health_shard_distance*life
			draw_set_transform(center+offset,style.health_shard_turn*life*sin(angle),Vector2.ONE*extent)
			draw_colored_polygon(_shards[index],Color(style.ivory,pow(1.0-life,2.0)))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)


func _draw_refill(center: Vector2, extent: float, phase: float, flash: float) -> void:
	var gather: float = smoothstep(0.0, 0.28, phase)
	var burst: float = smoothstep(0.30, 0.96, phase)
	var light: Color = style.heal_color.lerp(Color.WHITE, 0.65)
	var opacity: float = smoothstep(0.0, 0.09, phase) * (1.0 - smoothstep(0.43, 0.98, phase))
	for index: int in range(6):
		var ray: Vector2 = Vector2.from_angle(TAU * float(index) / 6.0 + PI * 0.25)
		var radius: float = lerpf(2.0, 0.45, gather) + burst * (1.45 + float(index % 2) * 0.38)
		var tip: Vector2 = center + ray * extent * radius
		var tail: Vector2 = tip - ray * extent * lerpf(0.65, 0.17, burst)
		draw_line(tail, tip, Color(style.ink, opacity * 0.85), 3.4, true)
		draw_line(tail, tip, Color(light, opacity), 1.6, true)
	if burst > 0.0:
		var ring_alpha: float = smoothstep(0.0, 0.12, burst) * (1.0 - burst)
		var radius: float = extent * lerpf(0.65, 2.2, burst)
		draw_arc(center, radius, 0.0, TAU, 24, Color(style.ink, ring_alpha), 3.4, true)
		draw_arc(center, radius, 0.0, TAU, 24, Color(light, ring_alpha), 1.6, true)
	if flash > 0.0:
		draw_circle(center, extent * 0.7, Color(light, flash * 0.48), true, -1.0, true)
		draw_line(center - Vector2.UP * extent, center + Vector2.UP * extent, Color(light, flash), 1.7, true)
		draw_line(center - Vector2.RIGHT * extent * 0.68, center + Vector2.RIGHT * extent * 0.68,
			Color(light, flash), 1.5, true)
