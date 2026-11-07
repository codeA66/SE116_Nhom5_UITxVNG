@tool
class_name HealthSegment
extends Control
## Đầu cáo có mõm/tai riêng: ô mất vẫn đọc được đường bao; mảnh vỡ tái dùng dữ liệu.
const Style = preload("res://resources/ui/hud_style.gd")
@export var style: Style = preload("res://resources/ui/hud_style.tres")
var filled: bool = true
var _age: float = INF
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
func set_filled(value: bool, animate: bool = true) -> void:
	if filled == value: return
	filled = value
	_age = 0.0 if animate else INF
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
	_clock += delta
	_animating = _age < maxf(style.health_transition_time,style.health_shard_time)
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
	var pulse: float = 1.0-style.health_pulse_amount*(0.5+0.5*sin(_clock*style.health_pulse_speed)) if _low else 1.0
	var fill_color: Color = style.empty_ink.lerp(style.ivory,t) if filled else style.ivory.lerp(style.empty_ink,t)
	if filled and _animating: fill_color = fill_color.lerp(style.heal_color,(1.0-t)*0.6)
	fill_color.a *= pulse
	if art != null:
		draw_texture_rect(art,Rect2(Vector2.ZERO,size),false,Color(1,1,1,pulse))
	else:
		draw_set_transform(center,0,Vector2.ONE*extent)
		draw_polyline(_outline,style.ink,(style.stroke_width()+clampf(style.health_shadow_width,0,4))/extent,true)
		draw_colored_polygon(_head,fill_color)
		draw_polyline(_outline,style.gold if filled else style.muted,style.stroke_width()/extent,true)
		if filled or t < 1.0:
			draw_line(Vector2(-0.56,-0.09),Vector2(-0.22,0.12),style.ink,style.stroke_width()/extent,true)
			draw_line(Vector2(0.56,-0.09),Vector2(0.22,0.12),style.ink,style.stroke_width()/extent,true)
			draw_colored_polygon(_nose,style.ink)
		if not filled and _age < style.health_crack_time:
			draw_polyline(_crack,style.damage_color,style.stroke_width()*1.5/extent,true)
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if not filled and _age < style.health_shard_time:
		var life: float = clampf(_age/maxf(style.health_shard_time,0.001),0,1)
		for index: int in range(clampi(style.health_shard_count,0,_shards.size())):
			var angle: float = float(index)*TAU/float(_shards.size())-PI*0.75
			var offset: Vector2 = Vector2(cos(angle),sin(angle))*style.health_shard_distance*life
			draw_set_transform(center+offset,style.health_shard_turn*life*sin(angle),Vector2.ONE*extent)
			draw_colored_polygon(_shards[index],Color(style.ivory,pow(1.0-life,2.0)))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
