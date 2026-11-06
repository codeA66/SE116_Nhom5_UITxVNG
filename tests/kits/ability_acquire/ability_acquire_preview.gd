extends Node3D
## USE CASE: nhận đủ chuỗi; lặp không rò; hủy trước/sau commit; đổi dữ liệu nguyên tố và cực trị.
## TEST CASE: 3 lượt gió, lửa, counts 0/max, màu tối/sáng, burst 0/max, thời gian ngắn/dài, hủy từng pha và pickup thật.
## NOTES: --verify chạy integration; --capture chụp camera game; --perf đo riêng không chụp trong cửa sổ burst.
## PackedScene đi trước alias script để tránh giữ vòng phụ thuộc khi kết thúc fixture.
const SEQUENCE_SCENE: PackedScene = preload("res://components/feedback/loot_beam/ability_acquire/ability_acquire_vfx.tscn")
const Sequence = preload("res://components/feedback/loot_beam/ability_acquire/ability_acquire_vfx.gd")
const Tuning = Sequence.Tuning
const BOOK_SCENE: PackedScene = preload("res://objects/core/pickups/ability/wind_spellbook_visual.tscn")
@export_group("Preview")
@export var floor_size: Vector2 = Vector2(16,16)
@export var floor_color: Color = Color("#293b45")
@export var source_position: Vector3 = Vector3(0,1.05,-1.3)
@export var settle_time: float = 0.4
@export var test_timeout: float = 90.0
@export var short_time: float = 0.025
@export var long_multiplier: float = 4.0
@export var capture_fraction: float = 0.5
@export var burst_capture_fraction: float = 0.22
@export var landing_capture_fraction: float = 0.88
@export var repeats: int = 3
@export var confirm_read_time: float = 0.7
@export var baseline_seconds: float = 2.0
@export var preview_heading: float = PI
@export var gather_capture_beats: PackedFloat32Array = PackedFloat32Array([0.1,0.45,0.82,0.96])
@export var orientation_tolerance: float = 0.99
@export var output: String = "user://ability_acquire"
var _world: Node3D
var _actor: Player
var _book: Node3D
var _sequence: Sequence
var _data: Tuning
var _wind: AbilityData
var _fire: AbilityData
var _selected: AbilityData
var _saved: PlayerProgress
var _verify: bool = false
var _capture_enabled: bool = false
var _perf: bool = false
var _headless: bool = false
var _played: bool = false
var _case: String = "manual"
var _phase: StringName
var _epoch: int = 0
var _fails: int = 0
var _grants: Dictionary[StringName,int] = {}
var _buttons: CanvasLayer
var _status: Label
var _samples: PackedFloat64Array = PackedFloat64Array()
var _sample_count: int = 0
var _measuring: bool = false
var _last_frame: int = 0
var _max_draws: float = 0.0
var _pickup_phase: StringName
var _reveal_started: int = 0
var _warmup_baseline: bool = false
## Deferred chờ autoload và save manager sẵn sàng trước khi tách tiến trình thử.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_run.call_deferred()
## Fixture tự khôi phục tiến trình; không ghi save thật của người dùng.
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--verify": _verify = true
		if arg == "--capture": _capture_enabled = true
		if arg == "--perf": _perf = true; _verify = true
		if arg == "--warmup-baseline": _warmup_baseline = true
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_headless = DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(output)
	_saved = GameState.progress.snapshot()
	if GameState.progress_committed.is_connected(SaveManager.save_game): GameState.progress_committed.disconnect(SaveManager.save_game)
	GameState.ability_unlocked.connect(_on_unlocked)
	_wind = load("res://abilities/wind_blast/wind_blast.tres") as AbilityData
	_fire = load("res://abilities/flame_breath/flame_breath.tres") as AbilityData
	_selected = _wind
	var clean: PlayerProgress = _saved.snapshot()
	clean.abilities.clear()
	GameState.replace_progress(clean)
	GameState.set_weapon(load("res://resources/combat/weapons/sword.tres") as WeaponData)
	_build_world()
	_data = Tuning.new()
	_sequence = SEQUENCE_SCENE.instantiate() as Sequence
	_sequence.data = _data
	_sequence.source_visual = _book
	_world.add_child(_sequence)
	_sequence.phase_started.connect(_on_phase)
	_sequence.burst_peaked.connect(_on_burst)
	_sequence.finished.connect(_on_finished)
	_sequence.ui.transfer_started.connect(_capture_transfer)
	_sequence.ui.icon_landed.connect(_capture_landing)
	_build_buttons()
	_buttons.visible = not _verify
	await get_tree().create_timer(settle_time,true,false,true).timeout
	var warmup: ShaderWarmup = ShaderWarmup.new()
	warmup.process_mode = Node.PROCESS_MODE_ALWAYS
	warmup.data = ShaderWarmupData.new()
	add_child(warmup)
	var started: int = Time.get_ticks_usec()
	if _warmup_baseline:
		_sequence.remove_from_group(ShaderWarmup.SOURCE_GROUP)
		_world.remove_child(_sequence)
	await warmup.run(self,get_viewport().get_camera_3d())
	print("ACQUIRE_WARMUP seconds=",float(Time.get_ticks_usec()-started)/1000000.0," headless=",_headless)
	warmup.queue_free()
	if _warmup_baseline:
		_sequence.free()
		GameState.replace_progress(_saved)
		get_tree().quit()
		return
	await get_tree().process_frame
	_actor.set_controls_enabled(true)
	if _verify:
		if _perf:
			Engine.max_fps = 0
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			_samples.resize(8192)
			_last_frame = Time.get_ticks_usec()
			set_process(true)
			_case = "idle_baseline"
			_measuring = true
			await get_tree().create_timer(baseline_seconds,true,false,true).timeout
			_measuring = false
			_report_burst()
		await _tests()
		set_process(false)
		_sequence.stop_all()
		GameState.replace_progress(_saved)
		print("ABILITY_ACQUIRE_RESULT fails=",_fails)
		_world.free()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit(1 if _fails else 0)
	else:
		_status.text = "Chọn kỹ năng rồi bấm Nhận kỹ năng. Enter để đóng bảng."
## Vẽ sàn và dùng nguyên Player/camera/HUD game, không tạo camera editor thay thế.
func _build_world() -> void:
	_world = Node3D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1
	_world.add_child(floor_body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(floor_size.x,0.2,floor_size.y)
	collision.shape = shape
	collision.position.y = -0.1
	floor_body.add_child(collision)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = floor_size
	floor_mesh.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = floor_color
	floor_mesh.material_override = mat
	_world.add_child(floor_mesh)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-25,0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	_world.add_child(sun)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#14232e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#a6c9d4")
	environment.environment.ambient_light_energy = 0.65
	_world.add_child(environment)
	_actor = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_world.add_child(_actor)
	_actor.model.rotation.y = preview_heading
	_actor.set_controls_enabled(false)
	_book = BOOK_SCENE.instantiate() as Node3D
	_book.position = source_position
	_world.add_child(_book)
## Nút preview dùng dữ liệu thật; ngoài lúc thử tự động không ép người dùng chờ timer.
func _build_buttons() -> void:
	_buttons = CanvasLayer.new()
	_buttons.layer = 30
	add_child(_buttons)
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(760,24)
	_buttons.add_child(row)
	var choices: OptionButton = OptionButton.new()
	choices.add_item(_wind.display_name)
	choices.add_item(_fire.display_name)
	choices.item_selected.connect(_select)
	row.add_child(choices)
	var play: Button = Button.new()
	play.text = "Nhận kỹ năng"
	play.pressed.connect(_replay)
	row.add_child(play)
	var stop: Button = Button.new()
	stop.text = "Dừng"
	stop.pressed.connect(_stop)
	row.add_child(stop)
	_status = Label.new()
	_status.position = Vector2(760,70)
	_buttons.add_child(_status)
## Đổi resource, không đổi code phase hay material family.
func _select(index: int) -> void:
	_selected = _wind if index == 0 else _fire
## Replay tái dùng chính renderer và pool, không instantiate hiệu ứng ở cú bùng.
func _replay() -> void:
	_begin(_selected,"manual")
## Preview có đường hủy đồng bộ như cảnh thật.
func _stop() -> void:
	_sequence.stop_all()
	_status.text = "Đã dừng và trả trạng thái."
## Mọi lượt test và nút preview đi qua cùng public API.
func _begin(ability: AbilityData, label: String) -> void:
	if not _sequence.is_idle(): return
	_case = label
	_phase = &""
	_epoch += 1
	_selected = ability
	if _played: _sequence.renderer.restore_source(false)
	_book.show()
	_played = true
	_check(_sequence.play(_actor,ability),"bắt đầu "+label)
## Commit trong preview mô phỏng đúng listener pickup thật, GameState tự chống trao trùng.
func _on_burst() -> void:
	GameState.unlock_ability(_selected)
## Chỉ đếm signal đã trao, không suy ra từ hình ảnh HUD.
func _on_unlocked(ability: AbilityData) -> void:
	_grants[ability.id] = _grants.get(ability.id,0) + 1
## Đo frame riêng với capture để ghi ảnh không làm lệch benchmark.
func _on_phase(phase: StringName) -> void:
	if _measuring and phase != _phase:
		_measuring = false
		_report_burst()
	_phase = phase
	if phase == &"Reveal": _reveal_started = Time.get_ticks_msec()
	if _perf and phase in [&"Gather",&"Burst"]:
		_sample_count = 0
		_max_draws = 0.0
		_measuring = true
	if _capture_enabled and not _perf: _capture_phase(phase,_epoch,_case)
	if _capture_enabled and not _perf and phase == &"Gather":
		for beat: float in gather_capture_beats: _capture_gather_beat(beat,_epoch,_case)
	if _capture_enabled and not _perf and phase == &"Settle": _capture_landing_dust(_epoch,_case)
	if is_instance_valid(_status): _status.text = String(phase)
## Screenshot lấy ở giữa pha và kiểm tra epoch để không chụp nhầm lượt sau.
func _capture_phase(phase: StringName, epoch: int, label: String) -> void:
	if _headless: return
	var duration: float = _duration(phase)
	var fraction: float = burst_capture_fraction if phase == &"Burst" else capture_fraction
	if phase == &"Reveal": duration = maxf(_data.panel_time,_data.title_time)+confirm_read_time; fraction = 0.8
	await get_tree().create_timer(maxf(duration*fraction,_data.minimum_time),true,false,true).timeout
	if epoch != _epoch or phase != _phase or _sequence.is_idle(): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(label+"_"+String(phase)+".png"))
## Chuỗi ảnh theo thời gian kiểm chứng hạt đang tụ và ánh sáng tăng, thay vì chỉ chọn một ảnh đẹp.
func _capture_gather_beat(fraction: float, epoch: int, label: String) -> void:
	if _headless: return
	await get_tree().create_timer(_data.gather_time*fraction,true,false,true).timeout
	if epoch != _epoch or _phase != &"Gather" or _sequence.is_idle(): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(label+"_Gather_%03d.png" % roundi(fraction*100.0)))
## Thời gian phục vụ fixture lấy cùng resource đang chạy.
func _duration(phase: StringName) -> float:
	var key: String = String(phase).to_snake_case()+"_time"
	if phase == &"Reveal": key = "panel_time"
	return float(_data.get(key))
## Chụp icon thật đang bay, không dựng một hình UI thay thế để minh họa.
func _capture_transfer() -> void:
	if not _capture_enabled or _perf or _headless: return
	var epoch: int = _epoch
	var label: String = _case
	await get_tree().create_timer(_data.fly_time*0.5,true,false,true).timeout
	if epoch != _epoch or _sequence.is_idle(): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(label+"_Transfer.png"))
## Chụp ngay khi slot nhận signal để kiểm chứng đường bay vào HUD thật.
func _capture_landing() -> void:
	if not _capture_enabled or _perf or _headless: return
	var label: String = _case
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(label+"_Slot.png"))
## Bụi tiếp đất nằm cuối pha hạ xuống, ảnh giữa pha không kiểm chứng được nhịp này.
func _capture_landing_dust(epoch: int, label: String) -> void:
	if _headless: return
	await get_tree().create_timer(_data.settle_time*landing_capture_fraction,true,false,true).timeout
	if epoch != _epoch or _phase != &"Settle" or _sequence.is_idle(): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(label+"_Land.png"))
## Status preview là sự kiện, không cần vòng process khi idle.
func _on_finished() -> void:
	if is_instance_valid(_status): _status.text = "Đã nhận kỹ năng."
## Mẫu đã cấp phát đủ trước combat; không append/resize ở frame được đo.
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _measuring and _sample_count < _samples.size():
		_samples[_sample_count] = float(now-_last_frame)/1000.0
		_sample_count += 1
		_max_draws = maxf(_max_draws,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_last_frame = now
## Chỉ sắp xếp sau khi hết cửa sổ đo.
func _report_burst() -> void:
	if _sample_count == 0: return
	var ordered: PackedFloat64Array = _samples.slice(0,_sample_count)
	ordered.sort()
	var total: float = 0.0
	for value: float in ordered: total += value
	print("ACQUIRE_PERF ",_case,"_",_phase," fps=",1000.0*_sample_count/total," first_ms=",_samples[0]," median_ms=",ordered[_sample_count >> 1]," p95_ms=",ordered[mini(_sample_count-1,floori(_sample_count*0.95))]," worst_ms=",ordered[-1]," draws=",_max_draws," samples=",_sample_count)
## Use case đầy đủ, lặp lại và chống trao trùng cùng dùng instance duy nhất.
func _tests() -> void:
	for index: int in range(repeats):
		_begin(_wind,"wind_%d" % (index+1))
		await _wait_finished(_sequence)
		_assert_clean(_sequence,"lặp gió")
		if index == 0 and _capture_enabled and not _perf and not _headless:
			await get_tree().create_timer(3.0,true,false,true).timeout
			_assert_clean(_sequence,"ba giây sau finished")
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output.path_join("after_three_seconds.png"))
	_check(_grants.get(_wind.id,0) == 1,"3 replay chỉ mở khóa gió một lần")
	_begin(_fire,"fire")
	await _wait_finished(_sequence)
	_assert_clean(_sequence,"đổi sang dữ liệu lửa")
	if _perf: return
	await _abort_tests()
	await _orientation_tests()
	await _extreme_tests()
	await _pickup_test()
	await _removal_tests()
	await _paused_test()
## Caller vốn đang pause phải nhận lại trạng thái pause, thay vì bị ép mở game.
func _paused_test() -> void:
	get_tree().paused = true
	_sequence.renderer.restore_source(false)
	_book.show()
	_check(_sequence.play(_actor,_wind),"phát khi caller đang pause")
	await get_tree().process_frame
	_sequence.stop_all()
	_check(get_tree().paused and _actor.controls_enabled,"hủy giữ pause có sẵn và trả controls")
	get_tree().paused = false
	_assert_clean(_sequence,"caller pause")
## Chờ theo frame cho phép UI đóng bằng đúng API, không thay phase bằng timer giả.
func _wait_finished(sequence: Sequence) -> void:
	var deadline: int = Time.get_ticks_msec()+int(test_timeout*1000.0)
	while not sequence.is_idle() and Time.get_ticks_msec()<deadline:
		if sequence.ui.is_waiting_for_confirm() and Time.get_ticks_msec()-_reveal_started > int((maxf(_data.panel_time,_data.title_time)+confirm_read_time)*1000.0): sequence.close_reveal()
		await get_tree().process_frame
	_check(sequence.is_idle(),"chuỗi kết thúc trước timeout")
## Hủy từng pha kiểm tra cả rollback và commit, không chỉ kiểm tra ảnh đen.
func _abort_tests() -> void:
	for phase: StringName in [&"Lift",&"Gather",&"Burst",&"Settle",&"Reveal"]:
		var ability: AbilityData = AbilityData.new()
		ability.id = StringName("abort_"+String(phase))
		ability.icon = _wind.icon
		ability.display_name = "Kiểm tra hủy"
		_begin(ability,"abort_"+String(phase))
		var deadline: int = Time.get_ticks_msec()+int(test_timeout*1000.0)
		while _phase != phase and Time.get_ticks_msec()<deadline: await get_tree().process_frame
		_sequence.stop_all()
		_assert_clean(_sequence,"hủy "+String(phase))
		_check(GameState.has_ability(ability.id) == (phase in [&"Burst",&"Settle",&"Reveal"]),"commit đúng khi hủy "+String(phase))
## Count 0/max và hai đầu màu/intensity chạy thật, không chỉ đọc thuộc tính.
func _extreme_tests() -> void:
	var saved: Array[float] = [_data.lift_time,_data.gather_time,_data.burst_time,_data.settle_time,_data.panel_time,_data.fly_time,_data.slot_time,_data.title_time]
	var counts: Vector3i = Vector3i(_data.mote_count,_data.spark_count,_data.dust_count)
	_set_times(short_time)
	_data.mote_count = 0
	_data.spark_count = 0
	_data.dust_count = 0
	_data.burst_intensity = 0.0
	var dark: AbilityData = _wind.duplicate(true) as AbilityData
	dark.accent_color = Color(0.005,0.005,0.005)
	_begin(dark,"zero_dark")
	await _wait_finished(_sequence)
	_assert_clean(_sequence,"zero count, dark, intensity zero")
	_data.mote_count = _data.pool_capacity
	_data.spark_count = _data.pool_capacity
	_data.dust_count = _data.pool_capacity
	_data.burst_intensity = _data.maximum_intensity
	var bright: AbilityData = _fire.duplicate(true) as AbilityData
	bright.accent_color = Color.WHITE
	_begin(bright,"max_bright")
	await _wait_finished(_sequence)
	_assert_clean(_sequence,"max count, bright, intensity max")
	_data.mote_count = counts.x
	_data.spark_count = counts.y
	_data.dust_count = counts.z
	_data.burst_intensity = 1.0
	_data.lift_time = saved[0]*long_multiplier
	_data.gather_time = saved[1]*long_multiplier
	_data.burst_time = saved[2]*long_multiplier
	_data.settle_time = saved[3]*long_multiplier
	_data.panel_time = saved[4]*long_multiplier
	_data.fly_time = saved[5]*long_multiplier
	_data.slot_time = saved[6]*long_multiplier
	_data.title_time = saved[7]*long_multiplier
	_begin(_wind,"long")
	await _wait_finished(_sequence)
	_assert_clean(_sequence,"thời gian dài")
	_data.lift_time=saved[0]; _data.gather_time=saved[1]; _data.burst_time=saved[2]; _data.settle_time=saved[3]
	_data.panel_time=saved[4]; _data.fly_time=saved[5]; _data.slot_time=saved[6]; _data.title_time=saved[7]
## Từ bốn hướng và parent đã xoay, mặt +Z phải hướng về camera rồi trả nguyên basis sau hủy.
func _orientation_tests() -> void:
	var initial: Transform3D = _actor.model.transform
	var actor_transform: Transform3D = _actor.transform
	var camera: Camera3D = get_viewport().get_camera_3d()
	for index: int in range(4):
		_actor.rotation.y = index*PI/6.0
		_actor.model.rotation.y = index*PI/2.0
		var before: Transform3D = _actor.model.transform
		_begin(_wind,"facing_%d" % index)
		await get_tree().create_timer(_data.facing_time+_data.minimum_time,true,false,true).timeout
		await get_tree().process_frame
		var toward: Vector3 = camera.global_position-_actor.model.global_position
		toward.y = 0.0
		var forward: Vector3 = _actor.model.global_basis.z
		forward.y = 0.0
		_check(forward.normalized().dot(toward.normalized())>orientation_tolerance,"mặt hướng camera, hướng đầu %d" % index)
		_sequence.stop_all()
		_check(_actor.model.transform.is_equal_approx(before),"hủy trả đủ transform, hướng đầu %d" % index)
	_actor.transform = actor_transform
	_actor.model.transform = initial
	_data.face_camera = false
	_begin(_wind,"facing_disabled")
	await get_tree().create_timer(_data.facing_time+_data.minimum_time,true,false,true).timeout
	_check(_actor.model.basis.is_equal_approx(initial.basis),"tắt tùy chọn quay không đổi basis")
	_sequence.stop_all()
	_data.face_camera = true
## Điều chỉnh tất cả mốc để thật sự đi qua trường hợp rất ngắn.
func _set_times(seconds: float) -> void:
	_data.lift_time=seconds; _data.gather_time=seconds; _data.burst_time=seconds; _data.settle_time=seconds
	_data.panel_time=seconds; _data.fly_time=seconds; _data.slot_time=seconds; _data.title_time=seconds
## Pickup thật phải giữ sách trước commit và chỉ ghi persistent flag ở đỉnh.
func _pickup_test() -> void:
	var pickup: AbilityPickup = (load("res://objects/core/pickups/ability/ability_pickup.tscn") as PackedScene).instantiate() as AbilityPickup
	var probe: AbilityData = _wind.duplicate(true) as AbilityData
	probe.id = &"pickup_probe"
	pickup.ability = probe
	pickup.persistent_id = &"preview.acquire.commit"
	_world.add_child(pickup)
	var sequence: Sequence = pickup.get_node("AbilityAcquireVfx") as Sequence
	await get_tree().process_frame
	(pickup.get_node("InteractableComponent") as InteractableComponent).interacted.emit(_actor)
	await get_tree().process_frame
	_check(not GameState.has_flag(pickup.persistent_id) and not GameState.has_ability(probe.id),"pickup chưa trao ở đầu lift")
	sequence.stop_all()
	_check(is_instance_valid(pickup) and (pickup.get_node("InteractableComponent") as InteractableComponent).enabled,"hủy trước đỉnh nhặt lại được")
	(pickup.get_node("InteractableComponent") as InteractableComponent).interacted.emit(_actor)
	var deadline: int = Time.get_ticks_msec()+int(test_timeout*1000.0)
	while not sequence.context.committed and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	_check(GameState.has_flag(pickup.persistent_id) and GameState.has_ability(probe.id),"pickup trao và ghi flag ở burst")
	sequence.stop_all()
	await get_tree().process_frame
	_check(not is_instance_valid(pickup),"hủy sau commit tiêu thụ pickup")
	_check(_grants.get(probe.id,0)==1,"pickup không trao trùng sau thử lại")
## Target/scene biến mất cũng phải trả pause và controls cho người chơi còn sống.
func _removal_tests() -> void:
	var target: Node3D = Node3D.new()
	_world.add_child(target)
	_sequence.renderer.restore_source(false)
	_book.show()
	_sequence.play(target,_wind)
	target.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_sequence.is_idle() and not get_tree().paused,"target gỡ giữa lift không để kẹt pause")
	var temporary: Node3D = Node3D.new()
	_world.add_child(temporary)
	var sequence: Sequence = SEQUENCE_SCENE.instantiate() as Sequence
	sequence.data = _data
	temporary.add_child(sequence)
	await get_tree().process_frame
	sequence.play(_actor,_wind)
	temporary.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not get_tree().paused and _actor.controls_enabled,"scene thoát trả quyền điều khiển")
## Đo hành vi cleanup công khai, kiểm tra cả transform và control đã trả lại.
func _assert_clean(sequence: Sequence, label: String) -> void:
	_check(sequence.is_idle() and sequence.renderer.get_active_slot_count()==0,label+": slot trả hết")
	_check(not get_tree().paused and _actor.controls_enabled,label+": pause/control phục hồi")
	_check(_actor.model.position.is_equal_approx(Vector3.ZERO),label+": model về đáy gốc")
## Gom lỗi để vẫn xem được các nhánh còn lại sau một assertion thất bại.
func _check(condition: bool, label: String) -> void:
	if not condition: _fails += 1
	print("PASS " if condition else "FAIL ",label)
