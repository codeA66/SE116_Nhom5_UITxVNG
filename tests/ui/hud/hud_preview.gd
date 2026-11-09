extends Node
## USE CASE: duyệt HUD bằng Player thật; hồ sơ thử riêng, không ghi save của người chơi.
## NOTES: --map dùng Map Gió; --capture chụp viewport; --perf lấy mẫu riêng không chụp.
const Style = preload("res://resources/ui/hud_style.gd")
const PLAYER: PackedScene = preload("res://entities/player/player.tscn")
@export_group("Preview")
@export var use_map: bool = true
@export var capture_on_start: bool = false
@export var benchmark_on_start: bool = false
@export var benchmark_controls: bool = false
@export var grant_test_loadout: bool = true
@export var output: String = "user://hud_review"
@export var settling_seconds: float = 8.0
@export var timeout_seconds: float = 90.0
@export var benchmark_seconds: float = 5.0
@export var sample_capacity: int = 10000
var actor: Player
var world: Node3D
var hud_style: Style
var saved_progress: PlayerProgress
var controls: CanvasLayer
var floor_visual: MeshInstance3D
var _samples: PackedFloat64Array = PackedFloat64Array()
## Deferred để SaveManager đã ready trước khi ngắt autosave.
func _ready() -> void:
	_preview.call_deferred()
## Preview có nút tạo tình huống, không chỉnh cơ chế combat trong project.
func _preview() -> void:
	configure_storage()
	await build_world(use_map)
	build_controls()
	if capture_on_start or OS.get_cmdline_user_args().has("--capture"):
		controls.hide()
		await get_tree().create_timer(settling_seconds).timeout
		await capture("after_1280x720")
		if benchmark_on_start or OS.get_cmdline_user_args().has("--perf"):
			if benchmark_controls: await measure_visibility("1280x720")
			else: await measure("after_1280x720")
		DisplayServer.window_set_size(Vector2i(1920,1080))
		await get_tree().create_timer(settling_seconds).timeout
		await capture("after_1920x1080")
		if benchmark_on_start or OS.get_cmdline_user_args().has("--perf"):
			if benchmark_controls: await measure_visibility("1920x1080")
			else: await measure("after_1920x1080")
		await cleanup()
		get_tree().quit()
## Hai lớp bảo vệ: ngắt autosave và chuyển storage trước khi thêm Player/khu.
func configure_storage() -> void:
	if GameState.progress_committed.is_connected(SaveManager.save_game): GameState.progress_committed.disconnect(SaveManager.save_game)
	SaveManager.use_storage_dir("user://test_hud/")
	saved_progress = GameState.progress.snapshot()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--capture-size=") and DisplayServer.get_name()!="headless":
			var axes: PackedStringArray = argument.trim_prefix("--capture-size=").split("x")
			if axes.size()==2 and axes[0].is_valid_int() and axes[1].is_valid_int():
				DisplayServer.window_set_size(Vector2i(axes[0].to_int(),axes[1].to_int()))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
## Dùng cùng Player và camera của game; màn phẳng chỉ phục vụ unit/integration nhanh.
func build_world(map_scene: bool) -> void:
	GameState.replace_progress(PlayerProgress.new())
	if grant_test_loadout:
		GameState.set_weapon(load("res://resources/combat/weapons/sword.tres") as WeaponData)
		GameState.add_weapon(load("res://resources/combat/weapons/bow.tres") as WeaponData)
		GameState.unlock_ability(load("res://abilities/wind_blast/wind_blast.tres") as AbilityData)
		GameState.unlock_ability(load("res://abilities/flame_breath/flame_breath.tres") as AbilityData)
	GameState.set_player_health(5)
	GameState.set_player_energy(4)
	if map_scene:
		world = (load("res://levels/zone_1_wind/level_1/level_1.tscn") as PackedScene).instantiate() as Node3D
		add_child(world)
		var deadline: int = Time.get_ticks_msec()+int(timeout_seconds*1000)
		while not world.call(&"is_combat_ready") and Time.get_ticks_msec()<deadline: await get_tree().process_frame
		assert(world.call(&"is_combat_ready"),"Map Gió chưa ready trước timeout")
		actor = world.get_node("Player") as Player
	else:
		world = Node3D.new()
		add_child(world)
		var floor_body: StaticBody3D = StaticBody3D.new()
		world.add_child(floor_body)
		var collider: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(80,0.2,80)
		collider.shape = shape
		collider.position.y = -0.1
		floor_body.add_child(collider)
		var mesh: MeshInstance3D = MeshInstance3D.new()
		floor_visual = mesh
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2(80,80)
		mesh.mesh = plane
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color("#637681")
		mesh.material_override = material
		world.add_child(mesh)
		var sun: DirectionalLight3D = DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-55,-25,0)
		world.add_child(sun)
		actor = PLAYER.instantiate() as Player
		world.add_child(actor)
	await get_tree().process_frame
	await get_tree().process_frame
	hud_style = (load("res://resources/ui/hud_style.tres") as Style).duplicate(true) as Style
	apply_style(hud_style)
## Style thử nghiệm là bản sao, không ghi ngược vào resource đang dùng trong editor.
func apply_style(value: Style) -> void:
	hud_style = value
	var root: Control = actor.get_node("HUD/GameHud") as Control
	root.set(&"style",hud_style)
	root.call(&"apply_style")
	for path: NodePath in [^"HUD/InteractionPrompt",^"HUD/HurtVignette"]:
		var widget: Node = actor.get_node(path)
		widget.set(&"style",hud_style)
		widget.call(&"apply_style")
## Nút preview chỉ dùng API component/signal đang có.
func build_controls() -> void:
	controls = CanvasLayer.new()
	add_child(controls)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(1030,25)
	controls.add_child(column)
	_add_button(column,"Mất 1 HP",actor.health.take_damage.bind(1))
	_add_button(column,"Hồi đầy",actor.health.heal_full)
	_add_button(column,"Còn 1 HP",actor.health.set_current_health.bind(1))
	_add_button(column,"Tiêu Linh lực",actor.energy.spend.bind(1))
	_add_button(column,"Nạp Linh lực",actor.energy.gain_from_hit)
	_add_button(column,"Thiếu Linh lực",actor.energy.notify_insufficient.bind(99))
	_add_button(column,"Soul Jade +137",GameState.add_currency.bind(&"soul_jade",137))
	_add_button(column,"Ghép Gió vào kiếm",GameState.fuse.bind(&"wind",WeaponData.Slot.SWORD))
	_add_button(column,"Ghép Lửa vào kiếm",GameState.fuse.bind(&"fire",WeaponData.Slot.SWORD))
## Callable giữ component thật; không mô phỏng các thuộc tính nội bộ của widget.
func _add_button(parent: Control, title: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = title
	button.pressed.connect(callback)
	parent.add_child(button)
## Ảnh lấy sau frame render, không resize ảnh để giả độ phân giải.
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(output.path_join(label+".png"))
	print("HUD_CAPTURE ",label," ",image.get_size())
## Pixel framebuffer dùng transform của viewport, khác tọa độ logic khi stretch 1080p.
func sample_canvas(image: Image,widget: Control,local_point: Vector2) -> Color:
	var pixel: Vector2 = get_viewport().get_stretch_transform()*widget.get_global_transform_with_canvas()*local_point
	return image.get_pixelv(Vector2i(pixel))
## Đồng hồ tường và bộ đệm cấp phát trước; benchmark không ghi ảnh trong cửa sổ đo.
func measure(label: String) -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_samples.resize(sample_capacity)
	var count: int = 0
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	var total: float = 0.0
	while count<sample_capacity and Time.get_ticks_usec()-started<benchmark_seconds*1000000:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		_samples[count] = float(now-previous)/1000.0
		total += _samples[count]
		count += 1
		previous = now
	var ordered: PackedFloat64Array = _samples.slice(0,count)
	ordered.sort()
	var result: Dictionary = {"fps":1000.0*count/total,"median_ms":ordered[count>>1],"p95_ms":ordered[mini(count-1,floori(count*0.95))],"worst_ms":ordered[-1],"samples":count,"size":label}
	print("HUD_PERF ",JSON.stringify(result))
	var file: FileAccess = FileAccess.open(output.path_join(label+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
## A/B xen kẽ trong cùng Map/Player, không đổi scene hoặc chụp ảnh giữa các cửa sổ đo.
func measure_visibility(label: String) -> void:
	var layer: CanvasLayer = actor.get_node("HUD") as CanvasLayer
	for index: int in range(4):
		layer.visible = index%2==1
		await get_tree().create_timer(1.0).timeout
		await measure(label+("_on_" if layer.visible else "_off_")+str(index))
	layer.show()
## Dọn scene trước khi thoát để callbacks/hình/vật lý không sống qua lượt sau.
func cleanup() -> void:
	GameState.replace_progress(saved_progress)
	if is_instance_valid(world): world.free()
	world = null
	actor = null
	await get_tree().process_frame
	await get_tree().process_frame
