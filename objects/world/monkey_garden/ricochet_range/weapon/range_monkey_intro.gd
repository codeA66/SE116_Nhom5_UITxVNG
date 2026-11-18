extends Node3D
## Diễn viên dùng rig grunt. Chuyển động được điều khiển riêng cho đoạn giới thiệu.

signal gun_dropped(at: Vector3)

const RIG := preload("res://assets/models/enemies/blenderimport/monkey_grunt/Monkey_Grunt.glb")
const ANIMATIONS := preload("res://assets/models/enemies/blenderimport/monkey_grunt/animations/all.tres")
const CUT := preload("res://levels/zone_1_wind/level_1/rooms/tier_3/test_runtime/tier3_camera_cut.gd")
const IDLE := &"Monkey_Grunt_Idle"
const WALK := &"Gorilla_Locomotion"
const RUN := &"Gorilla_Quadrupedal_Run_Fast"
const EDGE := 9.5
const ESCAPE_CORNER := Vector3(-13.15, 0, 7.5)
const ESCAPE_END := Vector3(-13.15, 0, -9.6)
const ESCAPE_SPEED := 10.5
const HELD_SIZE := 0.60
const REAR_GRIP := Vector3(0.0, 0.42, -0.4)

var _animator: AnimationPlayer
var _gun: Node3D
var _patrol: Tween
var _started := false

func setup(model: Node3D) -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var rig := RIG.instantiate() as Node3D
	rig.name = "Rig"
	rig.scale = Vector3.ONE * 0.38
	visual.add_child(rig)
	_animator = AnimationPlayer.new()
	add_child(_animator)
	_animator.add_animation_library(&"", ANIMATIONS)
	var skeleton: Skeleton3D
	for node in rig.find_children("*", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
		break
	_gun = model.duplicate(0) as Node3D
	if is_instance_valid(skeleton):
		var socket := BoneAttachment3D.new()
		socket.bone_name = &"CATRigRArmPalm001"
		skeleton.add_child(socket)
		var grip := Node3D.new()
		socket.add_child(grip)
		grip.basis = Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.UP, PI)
		grip.scale = Vector3.ONE * HELD_SIZE / socket.global_basis.get_scale().abs()
		grip.add_child(_gun)
		_gun.position = -REAR_GRIP
	else:
		add_child(_gun)
		_gun.scale *= HELD_SIZE
		_gun.position = Vector3(0.45, 1.15, 0.5)
	for knife in rig.find_children("*knife*", "MeshInstance3D", true, false):
		(knife as MeshInstance3D).hide()
	_gun.show()
	position.x = -EDGE
	_animator.play(IDLE)
	_patrol = create_tween().set_loops()
	for side in [1.0, -1.0]:
		_patrol.tween_callback(_walk_to.bind(side))
		_patrol.tween_property(self, "position:x", side * EDGE, 5.2)
		_patrol.tween_callback(_animator.play.bind(IDLE))
		_patrol.tween_interval(2.0)

func _walk_to(side: float) -> void:
	rotation.y = side * PI * 0.5
	_animator.play(WALK)

func begin(actor: Player) -> void:
	if _started:
		return
	_started = true
	_patrol.kill()
	_animator.play(IDLE)
	var camera := CUT.new()
	add_child(camera)
	var focus := global_position + Vector3.UP * 1.1
	await camera.start(actor, focus, Vector3(0, 5, 8), 13.5).finished
	var toward := actor.global_position - global_position
	var turn := create_tween().set_trans(Tween.TRANS_SINE)
	var angle := atan2(toward.x, toward.z)
	turn.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, angle), 0.35)
	turn.tween_interval(0.35)
	await turn.finished
	var floor_y := position.y
	var hop := create_tween()
	hop.tween_property(self, "position:y", floor_y + 0.55, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(self, "position:y", floor_y, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await hop.finished
	_gun.hide()
	gun_dropped.emit(global_position)
	await get_tree().create_timer(0.45, false).timeout
	_animator.play(RUN)
	await _run_to(Vector3(position.x, floor_y, ESCAPE_CORNER.z))
	await _run_to(ESCAPE_CORNER)
	await _run_to(ESCAPE_END)
	hide()
	await camera.finish()
	queue_free()

func _run_to(waypoint: Vector3) -> void:
	var travel := waypoint - position
	if travel.is_zero_approx():
		return
	rotation.y = atan2(travel.x, travel.z)
	var run := create_tween()
	run.tween_property(self, "position", waypoint, travel.length() / ESCAPE_SPEED)
	await run.finished
