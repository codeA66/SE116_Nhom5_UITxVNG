class_name ZoneRoot
extends Node3D
## Gốc của một khu (gắn vào node gốc mỗi scene khu). Khi khu tải xong, đặt player vào điểm xuất hiện
## mà SceneManager yêu cầu, hoặc điểm mặc định. Khu không cần tự chứa player.

## Player đã được đặt vào khu: hiệu ứng / camera / UI trong khu cần bám player thì nối signal này trong scene
signal player_spawned(player: Player)
signal combat_ready

const PLAYER_SCENE := preload("res://entities/player/player.tscn")

## Dùng khi vào khu không qua cổng hay checkpoint (mở game lần đầu, chạy thử scene bằng F6)
@export var default_spawn_id: StringName = &"start"
## Biên dịch sẵn shader lúc vào khu, khi màn còn tối (renderer Compatibility đứng hình ở lần đầu vẽ hiệu ứng).
## Để trống = bỏ qua
@export var shader_warmup: ShaderWarmupData = preload("res://resources/vfx/shader_warmup_default.tres")

var _combat_ready: bool = false


func _ready() -> void:
	var previous_mode: ProcessMode = process_mode
	process_mode = Node.PROCESS_MODE_DISABLED
	var spawn := SpawnPoint.find_in(self, SceneManager.consume_pending_spawn_id())
	if spawn == null:
		spawn = SpawnPoint.find_in(self, default_spawn_id)

	var player := get_node_or_null(^"Player") as Player
	if player == null:
		player = PLAYER_SCENE.instantiate() as Player
		add_child(player)
	var controls_were_enabled: bool = player.controls_enabled
	player.set_controls_enabled(false)
	player.prepare_for_combat()

	if spawn:
		player.teleport(spawn.global_position, spawn.get_facing())
	else:
		push_warning("%s: không có SpawnPoint '%s', player giữ vị trí ban đầu" % [name, default_spawn_id])
	player_spawned.emit(player)
	# Báo sẵn sàng sau khi biên dịch xong: SceneManager giữ màn tối tới lúc đó. Bỏ bước này thì lần đầu chém,
	# thổi gió, quái chết, hố hút... đều đứng hình 0.2-0.5 s vì shader mới được biên dịch giữa lúc chơi
	await _warm_up_shaders()
	SceneManager.notify_zone_ready()
	# Khi chuyển khu, chờ màn đen rút hết; F6 thì mở combat ngay sau warmup.
	if SceneManager.is_busy():
		await SceneManager.zone_changed
	process_mode = previous_mode
	player.set_controls_enabled(controls_were_enabled)
	_combat_ready = true
	combat_ready.emit()


func is_combat_ready() -> bool:
	return _combat_ready


func _warm_up_shaders() -> void:
	if shader_warmup == null:
		return
	var warmup := ShaderWarmup.new()
	warmup.process_mode = Node.PROCESS_MODE_ALWAYS
	warmup.data = shader_warmup
	add_child(warmup)
	await warmup.run(self, get_viewport().get_camera_3d())
	warmup.queue_free()
