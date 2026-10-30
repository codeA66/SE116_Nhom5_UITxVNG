extends Node
var _measuring: bool = false
var _measure_frames: int = 0
var _measure_sum_ms: float = 0.0
var _measure_max_ms: float = 0.0
var _measure_last_us: int = 0
## Sân thử kỹ năng Lửa: cho sẵn kiếm, Thổi Gió (E) và Phun Lửa (Q) để chơi thử ngay, không cần đi nhặt.
## Tắt tự lưu khi mở sân: cho kỹ năng thử ở đây không được ghi vào save thật đang chơi dở.

@export var weapon: WeaponData
## Kiểu Resource (không phải AbilityData): mảng trong .tscn ghi là Array[Resource], gán sai kiểu sẽ bị bỏ qua không báo
@export var abilities: Array[Resource] = []


func _ready() -> void:
	set_process(false)
	if GameState.progress_changed.is_connected(SaveManager.save_game):
		GameState.progress_changed.disconnect(SaveManager.save_game)
	if GameState.progress_committed.is_connected(SaveManager.save_game):
		GameState.progress_committed.disconnect(SaveManager.save_game)
	if weapon:
		GameState.add_weapon(weapon)
		GameState.set_weapon(weapon)
	call_deferred(&"_review")
	for ability in abilities:
		GameState.unlock_ability(ability as AbilityData)


@export_group("VFX Review")
@export var review_output: String = "user://flame_review"
@export var capture_times: Array[float] = [0.15, 0.3, 0.45, 0.65, 0.9]
@export var review_delay: float = 3.0
@export var review_reach: float = 4.5
@export var review_width: float = 2.4
@export var review_direction: Vector3 = Vector3(1.0, 0.0, 1.0)

func _review() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.has("--fire-review"):
		return
	var floor_mesh: MeshInstance3D = get_parent().get_node("Floor/MeshInstance3D") as MeshInstance3D
	var material: StandardMaterial3D = floor_mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	material.albedo_color = Color(0.07, 0.08, 0.10) if args.has("--dark") else Color(0.72, 0.70, 0.65)
	floor_mesh.material_override = material
	await get_tree().create_timer(review_delay).timeout
	var player: Player = get_parent().get_node("Player") as Player
	if player == null:
		push_error("Review: missing player")
		return
	var data: FlameBreathData = player.get_ability(&"flame_breath") as FlameBreathData
	data.reach = review_reach
	data.width = review_width
	for arg: String in args:
		if arg.begins_with("--reach="):
			data.reach = arg.trim_prefix("--reach=").to_float()
		if arg.begins_with("--width="):
			data.width = arg.trim_prefix("--width=").to_float()
		if arg.begins_with("--output="):
			review_output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(review_output)
	player.model.rotation.y = PI
	var baseline: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var measure_only: bool = args.has("--measure-only")
	if measure_only:
		_begin_measure()
		await get_tree().create_timer(1.0).timeout
		_end_measure("baseline")
		_begin_measure()
	var started_us: int = Time.get_ticks_usec()
	player.state_machine.transition_to(&"FlameBreath")
	player.face_instantly(review_direction.normalized())
	var forward: Vector3 = player.model.global_basis.z
	for i: int in range(0 if args.has("--no-targets") else 3):
		var dummy: Node3D = get_parent().get_node("Dummy%d" % (i + 1)) as Node3D
		dummy.global_position = player.global_position + forward * (1.5 + float(i))
	var images: Array[Image] = []
	var elapsed: float = 0.0
	for stamp: float in capture_times:
		elapsed = float(Time.get_ticks_usec() - started_us) / 1000000.0
		await get_tree().create_timer(maxf(stamp - elapsed, 0.001)).timeout
		while float(Time.get_ticks_usec() - started_us) / 1000000.0 < stamp:
			await get_tree().process_frame
		elapsed = stamp
		await RenderingServer.frame_post_draw
		if not measure_only:
			images.append(get_viewport().get_texture().get_image())
		print("FIRE_REVIEW t=", stamp, " actual_s=", float(Time.get_ticks_usec() - started_us) / 1000000.0, " fps=", Engine.get_frames_per_second(), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " baseline_draws=", baseline)
	if measure_only:
		_end_measure("cast")
	for i: int in range(images.size()):
		images[i].save_png(review_output.path_join("fire_%.2f.png" % capture_times[i]))
	get_tree().quit()



func _begin_measure() -> void:
	_measure_frames = 0
	_measure_sum_ms = 0.0
	_measure_max_ms = 0.0
	_measure_last_us = Time.get_ticks_usec()
	_measuring = true
	set_process(true)

func _end_measure(label: String) -> void:
	_measuring = false
	set_process(false)
	print("FIRE_BENCH ", label, " frames=", _measure_frames, " mean_ms=", _measure_sum_ms / maxf(float(_measure_frames), 1.0), " max_ms=", _measure_max_ms)

func _process(_delta: float) -> void:
	if not _measuring:
		return
	var now_us: int = Time.get_ticks_usec()
	var frame_ms: float = float(now_us - _measure_last_us) / 1000.0
	_measure_last_us = now_us
	_measure_frames += 1
	_measure_sum_ms += frame_ms
	_measure_max_ms = maxf(_measure_max_ms, frame_ms)
