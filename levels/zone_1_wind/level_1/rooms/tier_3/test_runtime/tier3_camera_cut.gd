extends Camera3D
## Camera dùng chung cho hai đoạn giới thiệu Tier 3.

const TRAVEL_TIME := 1.15
const RETURN_TIME := 0.85

var _previous: Camera3D
var _actor: Player
var _controls: bool

func start(actor: Player, focus: Vector3, offset: Vector3, framing: float, travel_time: float = TRAVEL_TIME) -> Tween:
	_actor = actor
	_controls = actor.controls_enabled
	actor.set_controls_enabled(false)
	_previous = get_viewport().get_camera_3d()
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	projection = Camera3D.PROJECTION_ORTHOGONAL
	if is_instance_valid(_previous):
		global_transform = _previous.global_transform
		far = _previous.far
		size = _previous_framing()
	else:
		global_position = focus + offset
		size = framing
	make_current()
	var target := Transform3D(Basis.looking_at(-offset), focus + offset)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_transform", target, travel_time)
	tween.tween_property(self, "size", framing, travel_time)
	return tween

func finish() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	if is_instance_valid(_previous):
		var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(self, "global_transform", _previous.global_transform, RETURN_TIME)
		tween.tween_property(self, "size", _previous_framing(), RETURN_TIME)
		tween.tween_property(self, "far", _previous.far, 0.2)
		await tween.finished
		if is_instance_valid(_previous):
			_previous.make_current()
	if is_instance_valid(_actor):
		_actor.set_controls_enabled(_controls)
	_actor = null
	queue_free()

func _previous_framing() -> float:
	var framing := _previous.size
	if _previous.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var depth := (_previous.global_position - _actor.global_position).dot(_previous.global_basis.z)
		framing = maxf(depth, 1.0) * 2.0 * tan(deg_to_rad(_previous.fov * 0.5))
	if keep_aspect == _previous.keep_aspect:
		return framing
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	return framing * aspect if keep_aspect == Camera3D.KEEP_WIDTH else framing / aspect

func _exit_tree() -> void:
	if is_instance_valid(_actor):
		_actor.set_controls_enabled(_controls)
