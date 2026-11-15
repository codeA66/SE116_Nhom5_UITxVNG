extends Node3D
## Năm cửa sàn dùng cùng vật liệu gạch của phòng hiến tế.

const CUT := preload("res://levels/zone_1_wind/level_1/rooms/tier_3/test_runtime/tier3_camera_cut.gd")
const FLAG := &"level_1.tier3_pedestals_revealed"
const PANEL_SIZE := Vector3(0.85, 0.18, 1.7)
const DEPTH := 2.3
const FLOOR_SLIDE_TIME := 0.9
const PEDESTAL_RISE_TIME := 1.65

var _pedestals: Array[OfferingPedestal]
var _panels: Array[MeshInstance3D]
var _wells: Array[MeshInstance3D]
var _surface: MultiMeshInstance3D
var _floor_material: ShaderMaterial
var _pedestal_heights: Array[float]
var _shown := false
var _persistent := false

func setup(pedestals: Array[OfferingPedestal], floors: Node3D, bananas: Node, persistent: bool, already_open: bool) -> void:
	_pedestals = pedestals
	_persistent = persistent
	_shown = already_open or (_persistent and GameState.has_flag(FLAG))
	if _shown:
		return
	_surface = floors.find_child("RuntimeFloorBatch*", false, false) as MultiMeshInstance3D
	if _surface == null:
		_shown = true
		return
	_floor_material = _surface.material_override as ShaderMaterial
	var tiled := _floor_material.duplicate() as ShaderMaterial
	var centers := PackedVector2Array()
	for pedestal in _pedestals:
		centers.append(Vector2(pedestal.global_position.x, pedestal.global_position.z))
		_make_panels(pedestal.global_position, _floor_material)
		_pedestal_heights.append(pedestal.position.y)
		pedestal.position.y -= DEPTH
		pedestal.interaction.enabled = false
	tiled.set_shader_parameter("offering_hatches", true)
	tiled.set_shader_parameter("hatch_centers", centers)
	_surface.material_override = tiled
	for node in bananas.get_children():
		if node is OfferingBanana:
			node.picked_up.connect(_reveal)

func _make_panels(center: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = PANEL_SIZE
	var well := MeshInstance3D.new()
	var pit := BoxMesh.new()
	pit.size = Vector3(1.7, 0.2, 1.7)
	well.mesh = pit
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("121b21")
	well.material_override = dark
	add_child(well)
	well.global_position = center - Vector3.UP * DEPTH
	_wells.append(well)
	for side in [-1.0, 1.0]:
		var panel := MeshInstance3D.new()
		panel.mesh = box
		panel.material_override = material
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(panel)
		panel.global_position = center + Vector3(side * 0.425, -0.108, 0.0)
		_panels.append(panel)

func _reveal(actor: Player) -> void:
	if _shown:
		return
	_shown = true
	var camera := CUT.new()
	add_child(camera)
	var center := _pedestals[2]
	var focus := center.global_position + Vector3.UP * (DEPTH + 0.78)
	# Mép cửa phía phòng mở đầu ở z=8; máy đặt sát sàn, ngoài khe cửa.
	await camera.start(actor, focus, Vector3(0, 0.18, 7.25), 2.65).finished
	camera.fov = rad_to_deg(2.0 * atan(camera.size * 0.5 / camera.global_position.distance_to(focus)))
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.far = 17.0
	var open := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in _panels.size():
		var panel := _panels[i]
		var travel := -0.88 if i % 2 == 0 else 0.88
		open.tween_property(panel, "position:x", panel.position.x + travel, FLOOR_SLIDE_TIME)
	await open.finished
	var rise := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in _pedestals.size():
		rise.tween_property(_pedestals[i], "position:y", _pedestal_heights[i], PEDESTAL_RISE_TIME)
	await rise.finished
	var close := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in _panels.size():
		var panel := _panels[i]
		var travel := 0.88 if i % 2 == 0 else -0.88
		close.tween_property(panel, "position:x", panel.position.x + travel, FLOOR_SLIDE_TIME)
	await close.finished
	restore_floor()
	if _persistent:
		GameState.set_flag(FLAG)
	await get_tree().create_timer(0.55, false).timeout
	camera.finish()

func restore_floor() -> void:
	if _panels.is_empty():
		return
	_shown = true
	_surface.material_override = _floor_material
	for panel in _panels:
		panel.hide()
		panel.queue_free()
	for well in _wells:
		well.hide()
		well.queue_free()
	_panels.clear()
	_wells.clear()
	for i in _pedestals.size():
		var pedestal := _pedestals[i]
		pedestal.position.y = _pedestal_heights[i]
		pedestal.interaction.enabled = not pedestal.is_active()
