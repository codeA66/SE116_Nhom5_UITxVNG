extends Node
## Chụp cùng scene, camera và phím của game; số đo tách khỏi lượt đọc framebuffer.
const SANDBOX: PackedScene = preload("res://tests/fire/sandbox/fire_sandbox.tscn")
const STAMPS: Array[float] = [0.05,0.10,0.14,0.20,0.30,0.45,0.60,0.80,2.50]
const FLOORS: Dictionary[String,Color] = {"bright":Color("#b8b2a6"),"dark":Color("#18262d")}
const SIZES: Array[Vector2i] = [Vector2i(1280,720),Vector2i(1920,1080)]
const CASES: Dictionary[String,Vector3] = {
	"small":Vector3(0.5,0.5,0.5),
	"large":Vector3(15,15,15),
	"wide":Vector3(15,1,2),
	"long":Vector3(0.5,1,15)
}

@export var output: String = "user://wind_blast_review"
@export var sample_window: float = 0.90
@export var bench_rounds: int = 3
@export var capture_fps: int = 60

var _player: Player
var _sandbox: ZoneRoot
var _visual: WindBlastVisual
var _pool: WindImpactPool
var _data: WindBlastData
var _began_us: int
var _active_count: int
var _push_count: int
var _failed: int
var _passed: int
var _grounded_at_burst: bool
var _began_physics_frame: int
var _active_at_charge: int
var _capture_only: bool
var _began_render_frame: int

## Chuyển thư mục lưu trước khi tạo Player để fixture không ghi vào save chơi.
func _ready() -> void:
	_run.call_deferred()

## Cùng đường input và dữ liệu của game; chỉ đo bản hình hiện tại.
func _run() -> void:
	SaveManager.use_storage_dir("user://test_wind_blast_review/")
	for progress_signal: Signal in [GameState.progress_changed,GameState.progress_committed]:
		if progress_signal.is_connected(SaveManager.save_game):
			progress_signal.disconnect(SaveManager.save_game)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	_capture_only = arguments.has("--frames-only")
	for argument: String in arguments:
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	_sandbox = SANDBOX.instantiate() as ZoneRoot
	_player = _sandbox.get_node(^"Player") as Player
	_pool = _player.get_node(^"Model/WindBlastArea/WindBlastVfx/ImpactPool") as WindImpactPool
	_visual = _player.get_node(^"WindBlastCone") as WindBlastVisual
	add_child(_sandbox)
	if not _sandbox.is_combat_ready():
		await _sandbox.combat_ready
	_player.wind_blast.charge_started.connect(_on_charge)
	_player.wind_blast.blast_started.connect(_on_active)
	_player.wind_blast.pushed.connect(_on_push)
	var source: WindBlastData = _player.get_ability(WindBlastData.ID) as WindBlastData
	_data = source.duplicate(true) as WindBlastData
	var slot: int = GameState.progress.abilities.find(source)
	GameState.progress.abilities[slot] = _data
	var floor_mesh: MeshInstance3D = _sandbox.get_node(^"Floor/MeshInstance3D") as MeshInstance3D
	var material: StandardMaterial3D = floor_mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	floor_mesh.material_override = material
	var graphical: bool = DisplayServer.get_name() != "headless"
	if graphical and not arguments.has("--checks-only"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		await _sleep(0.35)
		if not _capture_only:
			await _bench("cold_cast",true)
			await _wait_lockout()
			# Lượt thứ hai qua cả đuôi để driver đã thấy toàn bộ pass trước khi chụp mốc.
			await _bench("warm_cast",true)
			await _wait_lockout()
		for size: Vector2i in SIZES:
			DisplayServer.window_set_size(size)
			Engine.max_fps = capture_fps
			await _sleep(0.35)
			for floor_id: String in FLOORS:
				material.albedo_color = FLOORS[floor_id]
				await _sleep(0.18)
				await _capture_cast("%dp_%s" % [size.y,floor_id])
			if _capture_only:
				continue
			material.albedo_color = FLOORS["bright"]
			Engine.max_fps = 0
			for round_index: int in range(maxi(bench_rounds,1)):
				await _bench("%dp_idle_%d" % [size.y,round_index+1],false)
				await _bench("%dp_cast_%d" % [size.y,round_index+1],true)
				await _wait_lockout()
	if not _capture_only:
		await _check_geometry()
		await _check_air_and_wall()
		await _check_pool()
		await _check_repeat()
	print("WIND_GUST_RESULT passes=",_passed," fails=",_failed)
	_sandbox.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _failed==0 else 1)

## Input Map đi qua đúng state, hướng được cố định qua điểm chuột ngoài thân.
func _cast() -> void:
	_player.energy.set_current(_player.energy.get_max())
	var camera: Camera3D = get_viewport().get_camera_3d()
	get_viewport().warp_mouse(camera.unproject_position(_player.global_position+Vector3(5.0,0.0,0.0)))
	_began_us = 0
	Input.action_press(_data.input_action)
	var until: int = Time.get_ticks_msec()+2000
	while _began_us==0 and Time.get_ticks_msec()<until:
		await get_tree().physics_frame
	Input.action_release(_data.input_action)
	if _began_us==0:
		_check(false,"không nhận charge_started từ Input Map")

## Signal là mốc thời gian, tránh đo thêm thời gian input chờ physics.
func _on_charge(_wind: WindBlastData) -> void:
	_player.face_instantly(Vector3.RIGHT)
	_began_us = Time.get_ticks_usec()
	_began_physics_frame = Engine.get_physics_frames()
	_began_render_frame = Engine.get_process_frames()
	_active_at_charge = _active_count

## Dùng để phân biệt cast trên không và cast ở sàn.
func _on_active(_wind: WindBlastData) -> void:
	_active_count += 1
	_grounded_at_burst = _player.is_on_floor()

## Số lần đẩy phải đi qua receiver thật của sandbox.
func _on_push(_receiver: WindReceiverComponent) -> void:
	_push_count += 1

## Chụp framebuffer theo mốc, ghi thời gian thực để so ảnh công bằng.
func _capture_cast(label: String) -> void:
	var frames: Array[Image] = []
	var actual: Array[float] = []
	await _cast()
	if _began_us==0:
		return
	for stamp: float in STAMPS:
		if _capture_only:
			var target: int = _began_render_frame+ceili(stamp*capture_fps)
			while Engine.get_process_frames()<target:
				await get_tree().process_frame
		else:
			while float(Time.get_ticks_usec()-_began_us)/1000000.0<stamp:
				await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if _capture_only:
			actual.append(float(Engine.get_process_frames()-_began_render_frame)/capture_fps)
		else:
			actual.append(float(Time.get_ticks_usec()-_began_us)/1000000.0)
		frames.append(get_viewport().get_texture().get_image())
	for index: int in range(STAMPS.size()):
		var path: String = output.path_join("%s_%.2f.png" % [label,STAMPS[index]])
		var result: Error = frames[index].save_png(path)
		print("WIND_CAPTURE ",label," expected=",STAMPS[index]," actual=",actual[index]," size=",frames[index].get_size()," result=",result)

## Cùng cửa sổ đo idle và cast, không đọc ảnh trong cửa sổ đó.
func _bench(label: String,cast: bool) -> void:
	var start: int = Time.get_ticks_usec()
	if cast:
		await _cast()
		if _began_us==0:
			return
	var previous: int = start
	var max_ms: float = 0.0
	var count: int = 0
	var sum_draws: int = 0
	var max_draws: int = 0
	while float(previous-start)<sample_window*1000000.0:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		max_ms = maxf(max_ms,float(now-previous)/1000.0)
		var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		sum_draws += draws
		max_draws = maxi(max_draws,draws)
		count += 1
		previous = now
	print("WIND_BENCH ",label," frames=",count," mean_ms=",float(previous-start)/float(count)/1000.0," max_ms=",max_ms," mean_draws=",float(sum_draws)/float(count)," max_draws=",max_draws)

## Cùng bộ dữ liệu đòn đi vào va chạm và tỉ lệ lưới, kể cả trục không vuông.
func _check_geometry() -> void:
	var original: Vector3 = Vector3(_data.width,_data.height,_data.reach)
	var mesh: WindGustLayer = _visual.get_node(^"Tornado") as WindGustLayer
	var shape: CollisionShape3D = _player.wind_blast.get_node(^"CollisionShape3D") as CollisionShape3D
	for case_id: String in CASES:
		var extent: Vector3 = CASES[case_id]
		_data.width = extent.x
		_data.height = extent.y
		_data.reach = extent.z
		await _cast()
		await _wait_for_burst()
		var box: BoxShape3D = shape.shape as BoxShape3D
		var center: float = mesh.position.z
		_check(mesh.is_visible_in_tree() and is_equal_approx(mesh.cast_extent.x, box.size.x)
			and box.size.is_equal_approx(extent) and center >= 0.0 and center <= box.size.z,
			case_id+" lốc theo bề ngang và nằm trong tầm")
		await _snapshot("extreme_"+case_id)
		await _wait_lockout()
		await _wait_for_visual_cleanup()
		_check(_visuals_clean(),case_id+" dọn toàn bộ lớp")
	_data.width = original.x
	_data.height = original.y
	_data.reach = original.z

## Kiểm tra cast thật khi chân rời sàn và khi phía trước có tường.
func _check_air_and_wall() -> void:
	var home: Vector3 = _player.global_position
	_player.teleport(home+Vector3.UP*2.8,Vector3.RIGHT)
	await _cast()
	await _wait_for_burst()
	var tornado: MeshInstance3D = _visual.get_node(^"Tornado") as MeshInstance3D
	_check(not _grounded_at_burst and tornado.is_visible_in_tree(),"cast trên không vẫn hiện lốc")
	await _snapshot("air")
	await _wait_lockout()
	_player.teleport(home,Vector3.RIGHT)
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.25,2.5,4.0)
	shape.shape = box
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var model: BoxMesh = BoxMesh.new()
	model.size = box.size
	mesh.mesh = model
	wall.add_child(shape)
	wall.add_child(mesh)
	_sandbox.add_child(wall)
	wall.global_position = home+Vector3(0.85,1.25,0.0)
	await _cast()
	await _wait_for_burst()
	_check(_visual.is_playing() and _player.global_position.x<wall.global_position.x,"cast sát tường vẫn bung tại phía người chơi")
	await _snapshot("wall")
	await _wait_lockout()
	wall.queue_free()
	await _wait_for_visual_cleanup()
	_check(_visuals_clean(),"cast sát tường tắt sạch")

## Đặt mục tiêu sát cuối tầm để kiểm tra vệt áp lực ngay trong khung mục tiêu bị đẩy.
func _check_pool() -> void:
	var dummy: Node3D = _sandbox.get_node(^"Dummy1") as Node3D
	dummy.global_position = _player.global_position + Vector3.RIGHT * (_data.reach * 0.92)
	var pulse: MeshInstance3D = _visual.get_node(^"PressurePulse") as MeshInstance3D
	var far_contact: Array[bool] = []
	var observe_far_contact := func(receiver: WindReceiverComponent) -> void:
		if receiver.owner == dummy:
			far_contact.append(pulse.is_visible_in_tree() and is_equal_approx(pulse.scale.z, _data.reach))
	_player.wind_blast.pushed.connect(observe_far_contact)
	var total: int = _pool.get_child_count()
	var before: int = _push_count
	await _cast()
	await _wait_for_burst()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var used: int = _playing_impacts()
	_check(_push_count>before and used>0 and _pool.get_child_count()==total,"receiver được đẩy và dùng lại node trong pool")
	_player.wind_blast.pushed.disconnect(observe_far_contact)
	_check(far_contact == [true], "vệt áp lực đã phủ cuối tầm khi mục tiêu bị đẩy")
	await _snapshot("impact")
	if _player.wind_blast.is_active():
		await _player.wind_blast.blast_stopped
	await get_tree().process_frame
	var tornado: Node3D = _visual.get_node(^"Tornado") as Node3D
	var end_center: float = _data.reach - minf(_data.width, _data.reach) * 0.5
	_check(absf(tornado.position.z - end_center) < 0.04, "lốc tới cuối tầm khi hitbox tắt")
	await _sleep(2.5)
	_check(_playing_impacts()==0 and _pool.get_child_count()==total and _visuals_clean(),"sau 2,5 giây pool và các lớp đã nghỉ")
	await _snapshot("clean")

## Phát liên tiếp sát mốc hồi, xác nhận không tăng node hoặc bỏ đuôi.
func _check_repeat() -> void:
	var count: int = _active_count
	var child_count: int = _visual.get_child_count()
	for _index: int in range(4):
		await _cast()
		await _wait_lockout()
	await _wait_for_visual_cleanup()
	_check(_active_count==count+4 and _visual.get_child_count()==child_count and _visuals_clean(),"4 cast liên tiếp tái dùng cùng lớp")
	var tail: MeshInstance3D = _visual.get_node(^"Tornado") as MeshInstance3D
	await _cast()
	await _sleep(_data.duration+0.10)
	_check(tail.is_visible_in_tree() and _visual.is_playing(),"đuôi còn sau khi animation đòn kết thúc")
	await _sleep(2.5)
	_check(_visuals_clean(),"đuôi gió và impact nghỉ sau mốc dọn")
	await _snapshot("repeat_clean")

## Dọn được đánh giá từ node thực, không chỉ kiểm tra timer.
func _visuals_clean() -> bool:
	if _visual.visible or _visual.is_processing():
		return false
	for child: Node in _visual.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = child as GeometryInstance3D
		if geometry.visible or geometry.is_processing():
			return false
	return true

## Đếm node đang phát để bắt lỗi pool bị bỏ quên.
func _playing_impacts() -> int:
	var count: int = 0
	for child: Node in _pool.get_children():
		if (child as WindBurstVfx).playing:
			count += 1
	return count

## Giữ các lần cast sát giới hạn thật mà không chỉnh cooldown.
func _wait_lockout() -> void:
	var ready_frame: int = _began_physics_frame+ceili(_data.get_lockout()*Engine.physics_ticks_per_second)+2
	while Engine.get_physics_frames()<ready_frame:
		await get_tree().physics_frame

## Chờ mốc hitbox thực thay vì suy từ đồng hồ tường khi shader mới làm chậm khung.
func _wait_for_burst() -> void:
	var deadline: int = Time.get_ticks_msec()+1500
	while _active_count==_active_at_charge and Time.get_ticks_msec()<deadline:
		await get_tree().physics_frame
	await get_tree().process_frame

## Đo thời điểm lớp render nghỉ độc lập với thời điểm hồi kỹ năng.
func _wait_for_visual_cleanup() -> void:
	var deadline: int = Time.get_ticks_msec()+2500
	while not _visuals_clean() and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame

## Những ca hình đặc biệt dùng cùng camera gameplay.
func _snapshot(label: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var result: Error = frame.save_png(output.path_join(label+".png"))
	print("WIND_CASE_IMAGE ",label," size=",frame.get_size()," result=",result)

## Timer của fixture, không thay clock trong gameplay.
func _sleep(span: float) -> void:
	await get_tree().create_timer(span).timeout

## Báo từng kết quả cùng với mã thoát cho lần chạy tự động.
func _check(value: bool,label: String) -> void:
	if value:
		_passed += 1
	else:
		_failed += 1
	print("PASS " if value else "FAIL ",label)
