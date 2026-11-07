class_name BakaWeapon
extends Node
var arena: BananaRicochetRange
var _player: Player
var _visual: Node3D
var _hold: BananaGunHold
var _hidden: Array[Node3D] = []
var _active: bool = false
var _shot_left: float = 0.0
var _score: Label
var _ammo: Label
var _score_tween: Tween
var _laser: MeshInstance3D
var _camera: Camera3D
var _saved_camera: Camera3D
var _camera_active: bool=false
func _ready() -> void:
	_player = get_parent() as Player
	_visual = arena.get_node("GunPickup/Model").duplicate() as Node3D
	GardenRewards.fit(_visual)
	_hold = BananaGunHold.new(); _player.model.add_child(_hold); _hold.configure(_player,_visual)
	for path: String in ["WeaponSocket"]:
		var object: Node3D = _player.get_node_or_null(path) as Node3D
		if object: _hidden.append(object)
	var sword: Node3D=_player.model.find_child("Sword",true,false) as Node3D
	if sword: _hidden.append(sword)
	set_active(true)
	var hud: CanvasLayer=CanvasLayer.new(); hud.layer=21; add_child(hud)
	_score=Label.new(); _score.add_theme_font_size_override("font_size",24); _score.mouse_filter=Control.MOUSE_FILTER_IGNORE; hud.add_child(_score); _score.hide()
	_ammo=Label.new(); _ammo.add_theme_font_size_override("font_size",24); _ammo.modulate=Color.WHITE; _ammo.mouse_filter=Control.MOUSE_FILTER_IGNORE; hud.add_child(_ammo); _ammo.hide()
	_laser=MeshInstance3D.new(); _laser.mesh=BoxMesh.new(); var mat: StandardMaterial3D=StandardMaterial3D.new(); mat.albedo_color=Color(1,0.02,0.01); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; _laser.material_override=mat; _laser.top_level=true; _player.add_child(_laser)
	_camera=Camera3D.new(); _camera.projection=Camera3D.PROJECTION_ORTHOGONAL; _camera.size=30; _player.get_parent().add_child(_camera)
	arena.changed.connect(_changed); _changed(arena.ammo,arena.score)
func _changed(ammo: int, score: int) -> void:
	if _score==null: return
	_score.text=str(score); _ammo.text="Ammo: %d/%d"%[ammo,arena.magazine_size]
	_score.modulate=[Color.WHITE,Color("fff3a1"),Color("ffd22b"),Color("ff8c20"),Color("ff2424"),Color("ff2424")][mini(score,5)]
	_score.scale=Vector2.ONE
	if _score_tween: _score_tween.kill()
	# Raster ở cỡ chữ thật thay vì phóng lớn texture chữ nhỏ; mép trên giữ nguyên.
	var size: int=28+score*4
	var previous: int=_score.get_theme_font_size("font_size")
	_score_tween=create_tween()
	_score_tween.tween_method(_set_score_font,previous,size+6,0.12)
	_score_tween.tween_method(_set_score_font,size+6,size,0.2)
func _set_score_font(size: int) -> void:
	_score.add_theme_font_size_override("font_size",size)
	_score.reset_size()
func finish() -> void:
	var was_visible: bool=_score.visible
	set_active(false); _score.text="5"; _score.visible=was_visible
	_congratulate()
	GardenCombatEffects.confetti(_player.get_parent() as Node3D,arena.to_global(Vector3(-2,2.5,-13)))
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		_score.hide(); _ammo.hide()
		if is_instance_valid(_visual): _visual.queue_free()
		_laser.hide()
		if _camera_active and is_instance_valid(_saved_camera): _saved_camera.make_current()
		_camera_active=false)
func set_active(value: bool) -> void:
	if not is_instance_valid(_player): return
	if not is_instance_valid(_visual): value=false
	_active = value
	_player.set_combat_locked(self,value)
	_hold.set_held(value)
	if is_instance_valid(_visual): _visual.visible = value
	for object: Node3D in _hidden:
		if is_instance_valid(object):
			object.visible = not value and (object.name != "Sword" or (_player.get_weapon() != null and _player.get_weapon().slot == WeaponData.Slot.SWORD))
	if _score: _score.hide(); _ammo.hide(); _laser.visible=value
	set_physics_process(value); set_process_input(value)
func _physics_process(delta: float) -> void:
	_shot_left = maxf(_shot_left-delta,0.0)
	var direction: Vector3 = _player.get_mouse_aim_direction()
	if _camera_active:
		var mouse: Vector2=_player.get_viewport().get_mouse_position(); var at: Variant=Plane(Vector3.UP,_player.global_position.y).intersects_ray(_camera.project_ray_origin(mouse),_camera.project_ray_normal(mouse))
		if at!=null: direction=((at as Vector3)-_player.global_position).normalized()
	if not direction.is_zero_approx():
		_player.face_direction(direction,delta)
	var origin: Vector3=_hold.muzzle.global_position
	if direction.is_zero_approx(): direction=_player.get_facing_direction()
	var hit: Dictionary=_player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*40,1))
	var end: Vector3=hit.position if not hit.is_empty() else origin+direction*40
	_laser.global_position=(origin+end)*0.5; _laser.look_at(end); (_laser.mesh as BoxMesh).size=Vector3(0.025,0.025,maxf(origin.distance_to(end),0.01))
	var local: Vector3=arena.to_local(_player.global_position)
	var near: bool=local.z>5.2 and local.z<8.0 and absf(local.x)<11
	if near and not _camera_active: _saved_camera=_player.get_viewport().get_camera_3d(); _camera.global_transform=_saved_camera.global_transform; _camera.make_current(); _camera_active=true
	if near:
		_camera.global_position=_camera.global_position.lerp(arena.global_position+Vector3(0,29,12),1-exp(-delta*5)); _camera.look_at(arena.global_position+Vector3(0,0,-1))
	elif _camera_active:
		_saved_camera.make_current(); _camera_active=false
	var arrived: bool=_camera_active and _camera.is_current() and _camera.global_position.distance_to(arena.global_position+Vector3(0,29,12))<0.35
	_score.visible=arrived; _ammo.visible=arrived
	if arrived:
		_score.position=_camera.unproject_position(arena.to_global(Vector3(-3.6,2.7,-13)))-Vector2(_score.size.x*0.5,50)
		_ammo.position=_camera.unproject_position(arena.to_global(Vector3(3.6,2.7,-13)))-Vector2(_ammo.size.x*0.5,_ammo.size.y)
func _input(event: InputEvent) -> void:
	if not _active or not _player.controls_enabled or not event.is_action_pressed("attack") or _shot_left > 0: return
	var carry: CarryComponent = _player.get_node_or_null("CarryComponent") as CarryComponent
	if carry != null and carry.held_item != null: return
	var toward: Vector3 = _player.get_mouse_aim_direction()
	if _camera_active:
		var point: Variant=Plane(Vector3.UP,_player.global_position.y).intersects_ray(_camera.project_ray_origin(_player.get_viewport().get_mouse_position()),_camera.project_ray_normal(_player.get_viewport().get_mouse_position()))
		if point!=null: toward=((point as Vector3)-_player.global_position).normalized()
	if toward.is_zero_approx(): toward = _player.get_facing_direction()
	_player.face_instantly(toward)
	if arena.fire(_hold.muzzle.global_position,toward):
		_shot_left = 0.24
	get_viewport().set_input_as_handled()
func _congratulate() -> void:
	var message: Label3D=Label3D.new(); message.name="Congratulations"
	message.text="Congratulations!"; message.font_size=64; message.pixel_size=0.006
	message.billboard=BaseMaterial3D.BILLBOARD_ENABLED; message.no_depth_test=true
	message.modulate=Color("fff1b0"); message.outline_modulate=Color("172d3c")
	message.outline_size=10; arena.add_child(message); message.position=Vector3(0,2.1,7)
	var tween: Tween=message.create_tween(); tween.set_parallel(true)
	tween.tween_property(message,"position:y",3.8,2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(message,"modulate:a",0.0,1.8).set_delay(0.6)
	tween.tween_property(message,"outline_modulate:a",0.0,1.8).set_delay(0.6)
	tween.chain().tween_callback(message.queue_free)
