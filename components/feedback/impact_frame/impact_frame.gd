extends Node
## Autoload "ImpactFrame": hiệu ứng nháy anime đen-trắng / đảo âm bản + speed-lines chuẩn OpenGL 3.3 Compatibility.
## Chạy theo thời gian thực để hoạt động mượt song song với HitStop; tự tắt process khi rảnh.

signal triggered
signal finished

const SHADER := preload("res://components/feedback/impact_frame/impact_frame.gdshader")
const MAX_REAL_STEP := 0.05

var _layer: CanvasLayer
var _rect: ColorRect
var _mat: ShaderMaterial
var _elapsed: float = 0.0
var _duration: float = 0.24
var _last_usec: int = 0
var _active: bool = false


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "ImpactFrameLayer"
	_layer.layer = 95
	add_child(_layer)

	_rect = ColorRect.new()
	_rect.name = "ImpactFrameRect"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	_rect.hide()
	_layer.add_child(_rect)
	set_process(false)


func _process(_delta: float) -> void:
	if not _active:
		set_process(false)
		return
	# Đo thời gian thực bằng đồng hồ hệ thống để hoàn toàn miễn nhiễm với bước nhảy Engine.time_scale từ HitStop.
	var now_usec := Time.get_ticks_usec()
	var real_delta := clampf(float(now_usec - _last_usec) * 0.000001, 0.0, MAX_REAL_STEP)
	_last_usec = now_usec
	_elapsed += real_delta
	var p := clampf(_elapsed / maxf(_duration, 0.05), 0.0, 1.0)
	if p >= 1.0:
		stop()
		return
	_apply_frame(p)


func play_at(world_pos: Vector3, duration: float = 0.36, hitstop_duration: float = 0.13) -> void:
	var screen_uv := Vector2(0.5, 0.5)
	var camera := get_viewport().get_camera_3d()
	if camera and not camera.is_position_behind(world_pos):
		var vp_size := get_viewport().get_visible_rect().size
		if vp_size.x > 1.0 and vp_size.y > 1.0:
			var projected := camera.unproject_position(world_pos)
			screen_uv = Vector2(clampf(projected.x / vp_size.x, 0.15, 0.85), clampf(projected.y / vp_size.y, 0.15, 0.85))
	play(screen_uv, duration, hitstop_duration)


func play(center_uv: Vector2 = Vector2(0.5, 0.5), duration: float = 0.36, hitstop_duration: float = 0.13) -> void:
	_duration = maxf(duration, 0.08)
	_elapsed = 0.0
	_last_usec = Time.get_ticks_usec()
	_active = true
	_mat.set_shader_parameter(&"center_uv", center_uv)
	_apply_frame(0.0)
	_rect.show()
	set_process(true)
	triggered.emit()
	if hitstop_duration > 0.0:
		HitStop.stop(hitstop_duration)


func is_active() -> bool:
	return _active


func stop() -> void:
	var was_active := _active
	_active = false
	_elapsed = 0.0
	_mat.set_shader_parameter(&"intensity", 0.0)
	_mat.set_shader_parameter(&"color_accent", 0.0)
	_rect.hide()
	set_process(false)
	if was_active:
		finished.emit()


func _apply_frame(p: float) -> void:
	# Nhịp anime 4 pha (kéo dài uy lực hơn + điểm sắc đỏ rực & vàng kim ở các frame sau):
	# 0.00..0.20: Flash trắng-đen thuần tương phản cực mạnh
	# 0.20..0.48: Đảo âm bản đen nền / trắng hình + tia speed-lines sắc nét
	# 0.48..0.82: Các impact frame sau nháy nhịp đảo âm bản xen flash, điểm tia & viền đỏ-vàng rực cháy
	# 0.82..1.00: Nhả nhanh về màu game kèm dư ảnh ánh vàng-đỏ
	var invert := 0.0
	if (p >= 0.20 and p < 0.48) or (p >= 0.48 and p < 0.64) or (p >= 0.72 and p < 0.84):
		invert = 1.0
	var accent := 0.0
	if p >= 0.46:
		accent = smoothstep(0.46, 0.56, p) * (1.0 - smoothstep(0.86, 1.0, p))
	var env := 1.0 if p < 0.82 else (1.0 - smoothstep(0.82, 1.0, p))
	var contrast_val := lerpf(9.8, 6.2, smoothstep(0.78, 1.0, p))
	var dist_val := lerpf(0.024, 0.007, p)
	_mat.set_shader_parameter(&"intensity", env)
	_mat.set_shader_parameter(&"invert_amount", invert)
	_mat.set_shader_parameter(&"color_accent", accent)
	_mat.set_shader_parameter(&"contrast", contrast_val)
	_mat.set_shader_parameter(&"boost", 1.55 if invert > 0.5 else 1.38)
	_mat.set_shader_parameter(&"distortion", dist_val)
	_mat.set_shader_parameter(&"speedline_pan", p * 2.6)
