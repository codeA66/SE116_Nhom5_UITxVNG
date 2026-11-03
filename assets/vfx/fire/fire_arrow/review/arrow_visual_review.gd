extends Node3D
## DONE 2026-10-31: test vệt mặc định qua cùng một instance pool, không sửa scene đạn/player.
## NOT DONE: phần Model/impact của tên không thuộc API này.
## NOTES: --output= lưu ảnh; chạy headless kiểm tra logic, chạy native kiểm tra hiển thị.
@export var shots: int = 8
@export var shot_speed: float = 10.0
@export var shot_lifetime: float = 0.45
@export var output: String = "user://arrow_visual_review"
var fails: int = 0
var arrows: ObjectPool
var effects: ObjectPool
var first_arrow: ArrowProjectile
var attack: AttackData

## Chờ autoload sẵn rồi tạo pool nhỏ nhất để bắt buộc tái sử dụng.
func _ready() -> void:
	_run.call_deferred()

## Fire/plain xen kẽ, kiểm tra suốt flight/fade và sau ba giây.
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name() != "headless":
		var camera: Camera3D = Camera3D.new()
		camera.position=Vector3(0,6,7)
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=10.0
		add_child(camera)
		camera.look_at(Vector3(0,1,2))
		camera.make_current()
	arrows=ObjectPool.new()
	arrows.scene=load("res://objects/combat/projectiles/wind_arrow/wind_arrow.tscn") as PackedScene
	arrows.initial_size=1
	arrows.configure_instance=_configure_arrow
	add_child(arrows)
	effects=ObjectPool.new()
	effects.scene=load("res://assets/vfx/fire/fire_arrow/fire_arrow_trail.tscn") as PackedScene
	effects.initial_size=1
	add_child(effects)
	attack=AttackData.new()
	attack.damage=1
	await get_tree().create_timer(0.1).timeout
	for i: int in range(shots):
		await _shot(i,i % 2 == 0)
	await _shot(shots,true)
	await get_tree().create_timer(3.0).timeout
	_check(arrows.get_total_created()==1,"nhiều lượt vẫn chỉ một arrow instance")
	_check(effects.get_total_created()==1,"nhiều lượt vẫn chỉ một FireArrowTrail instance")
	_check(arrows.get_active_count()==0 and effects.get_active_count()==0,"sau 3 giây hai pool không còn đối tượng bận")
	_check(not first_arrow.is_visible_in_tree() and not first_arrow.is_physics_processing(),"tên đã ẩn và nghỉ")
	for node: Node in effects.get_children():
		var flames: GPUParticles3D=node.get_node("Flames") as GPUParticles3D
		_check(not node.is_processing() and not flames.emitting and not flames.is_visible_in_tree(),"VFX lửa đã ẩn, ngừng hạt và xử lý")
	await _capture("after_three")
	print("ARROW_VISUAL_RESULT fails=",fails)
	get_tree().quit(1 if fails else 0)

## Chỉ bỏ collision và impact trong fixture; tốc độ/lifetime vẫn đi qua launch thật.
func _configure_arrow(node: Node) -> void:
	var arrow: ArrowProjectile=node as ArrowProjectile
	arrow.collision_mask=0
	arrow.target_mask=0
	arrow.impact_scene=null
	arrow.impact_scale=0.0

## Kiểm tra renderer flag từng frame, vì chỉ ẩn một lần sẽ bị _set_trail_length bật lại.
func _shot(index: int, fire: bool) -> void:
	var arrow: ArrowProjectile=arrows.acquire() as ArrowProjectile
	if first_arrow==null: first_arrow=arrow
	_check(arrow==first_arrow,"tái sử dụng cùng arrow lượt %d" % index)
	if not arrow.finished.is_connected(arrows.release): arrow.finished.connect(arrows.release)
	arrow.global_position=Vector3(0,1,0)
	arrow.launch(attack,shot_speed,shot_lifetime,Vector3.BACK,self,arrow.global_position)
	if fire:
		var fx: FireArrowTrail=effects.acquire() as FireArrowTrail
		if fx.finished.get_connections().is_empty(): fx.finished.connect(effects.release.bind(fx))
		fx.start(arrow)
	_check((arrow.get_node("Model") as Node3D).visible,"API giữ nguyên model tên")
	var trail: MeshInstance3D=arrow.get_node("Trail") as MeshInstance3D
	var started: int=Time.get_ticks_usec()
	var failed_frame: bool=false
	var shown_plain: bool=false
	var captured: bool=false
	while arrows.get_active_count()>0 and Time.get_ticks_usec()-started<2000000:
		await get_tree().physics_frame
		var elapsed: float=float(Time.get_ticks_usec()-started)/1000000.0
		if fire:
			if trail.visible: failed_frame=true
			for particle: CPUParticles3D in arrow.flight_particles:
				if particle.visible or particle.emitting: failed_frame=true
		elif elapsed>0.08 and elapsed<shot_lifetime*0.8:
			shown_plain=shown_plain or trail.visible
			for particle: CPUParticles3D in arrow.flight_particles:
				if not particle.visible or not particle.emitting: failed_frame=true
		if not captured and elapsed>0.16:
			captured=true
			if index<2: await _capture("fire_flight" if fire else "plain_flight")
	_check(not failed_frame,"vệt/hạt gốc tắt xuyên suốt fire" if fire else "hạt gốc hoạt động lại ở plain")
	if not fire: _check(shown_plain,"plain sau fire hiện lại vệt")
	_check(arrows.get_active_count()==0,"tên hết lifetime và về pool")
	_check(arrow.global_position.distance_to(Vector3(0,1,shot_speed*shot_lifetime))<0.01,"quãng bay vẫn bằng tốc độ nhân lifetime")
	_check(attack.damage==1,"API không đổi dữ liệu sát thương")
	await get_tree().create_timer(0.4).timeout
	_check(effects.get_active_count()==0,"fire VFX kết thúc qua signal finished có một tham số")

## Ảnh native để đối chiếu vệt; không chụp khi headless.
func _capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(label+".png"))

## Không dừng sớm để kiểm tra đủ chuỗi tái sử dụng.
func _check(passed: bool,label: String) -> void:
	if not passed: fails+=1
	print("PASS " if passed else "FAIL ",label)
