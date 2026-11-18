extends Node
## Autoload "SceneManager": chuyển khu có màn mờ đen, ghi nhớ điểm xuất hiện cho khu mới,
## và hồi sinh tại checkpoint. Phải đứng sau GameState trong danh sách autoload.

signal zone_changed(zone_path: String)
## ZoneRoot của khu mới đã đặt player xong, có thể sáng màn hình
signal zone_ready

const FADE_LAYER_SCENE := preload("res://ui/transition/fade_layer.tscn")
const LOADING_SCREEN_SCENE: PackedScene = preload("res://ui/transition/loading_screen.tscn")
const PHYSICS_DRAIN := preload("res://ui/transition/scene_physics_drain.gd")
## Scene không có ZoneRoot sẽ không báo zone_ready: chờ tối đa chừng này frame rồi vẫn sáng lại
const ZONE_READY_TIMEOUT_FRAMES := 30
## Khu đầu tiên của game: mở game lần đầu, hoặc chết khi chưa chạm checkpoint nào.
## Khai báo duy nhất ở đây; đổi khu đầu game chỉ sửa dòng này
const START_ZONE := "res://levels/temple_center/hub/hub.tscn"

@export var fade_duration: float = 0.25

var _pending_spawn_id: StringName = &""
var _busy: bool = false
var _zone_ready: bool = false
## Lần đổi khu tới là hồi sinh: khôi phục tiến trình về checkpoint lúc màn đã tối
var _restore_on_load: bool = false
var _fade: FadeLayer
var _loading_screen: LoadingScreen


func _ready() -> void:
	_fade = FADE_LAYER_SCENE.instantiate() as FadeLayer
	add_child(_fade)
	_loading_screen = LOADING_SCREEN_SCENE.instantiate() as LoadingScreen
	add_child(_loading_screen)


func is_busy() -> bool:
	return _busy


## Chuyển sang khu khác; player xuất hiện tại SpawnPoint có tên spawn_id (rỗng = điểm mặc định của khu)
func change_zone(zone_path: String, spawn_id: StringName = &"") -> void:
	if _busy:
		return
	if not ResourceLoader.exists(zone_path):
		push_error("SceneManager: không tìm thấy khu '%s'" % zone_path)
		return
	_busy = true
	var illustrated: bool = _loading_screen.supports_zone(zone_path)
	var packed: PackedScene
	if illustrated:
		var request_error: Error = ResourceLoader.load_threaded_request(zone_path, "PackedScene")
		await _loading_screen.present(zone_path, fade_duration)
		if request_error == OK:
			var progress: Array = []
			var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(zone_path, progress)
			while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if not progress.is_empty():
					_loading_screen.set_load_progress(float(progress[0]))
				await get_tree().process_frame
				status = ResourceLoader.load_threaded_get_status(zone_path, progress)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				packed = ResourceLoader.load_threaded_get(zone_path) as PackedScene
				_loading_screen.set_load_progress(1.0)
		if packed == null:
			_restore_on_load = false
			push_error("SceneManager: không tải được '%s'" % zone_path)
			await _loading_screen.dismiss(fade_duration)
			_busy = false
			return
	else:
		await _fade.fade_out(fade_duration)
	var physics_drain := PHYSICS_DRAIN.new()
	await physics_drain.prepare(get_tree().current_scene)
	# Hồi sinh: tiến trình về bản chốt ở checkpoint, làm lúc màn đã tối để không thấy cổng / vật đổi trạng thái.
	# Chuyển khu thường thì giữ nguyên tiến trình đang chơi
	if _restore_on_load:
		_restore_on_load = false
		GameState.restore_checkpoint()
	_pending_spawn_id = spawn_id
	_zone_ready = false
	var error: Error
	if illustrated:
		error = get_tree().change_scene_to_packed(packed)
	else:
		error = get_tree().change_scene_to_file(zone_path)
	if error != OK:
		await physics_drain.restore()
		push_error("SceneManager: không tải được '%s' (%s)" % [zone_path, error])
		_pending_spawn_id = &""
		await _reveal_zone(illustrated)
		_busy = false
		return
	physics_drain.clear()
	await get_tree().scene_changed
	var zone := get_tree().current_scene
	# Khu có hợp đồng chuẩn bị combat phải báo xong, không bị cắt sau 30 frame.
	if zone != null and zone.has_method(&"is_combat_ready"):
		while not _zone_ready and is_instance_valid(zone) and zone.is_inside_tree():
			await get_tree().process_frame
		if not _zone_ready:
			await _reveal_zone(illustrated)
			_busy = false
			return
	var waited_frames := 0
	while not _zone_ready and waited_frames < ZONE_READY_TIMEOUT_FRAMES:
		await get_tree().process_frame
		waited_frames += 1
	if not _zone_ready:
		push_warning("SceneManager: '%s' không có ZoneRoot báo sẵn sàng, vẫn sáng màn hình" % zone_path)
	elif illustrated:
		_loading_screen.complete_load()
	await _reveal_zone(illustrated)
	_busy = false
	zone_changed.emit(zone_path)


func _reveal_zone(illustrated: bool) -> void:
	if illustrated:
		await _loading_screen.dismiss(fade_duration)
	else:
		await _fade.fade_in(fade_duration)


## Hồi sinh tại checkpoint gần nhất (kể cả khi đang ở khu khác); chưa có checkpoint thì về khu đầu game
func respawn_at_checkpoint() -> void:
	if _busy:
		return
	_restore_on_load = true
	go_to_last_checkpoint()


## Dịch chuyển player trong cùng khu (vòng xoáy ra khỏi phòng đánh): tối màn, đặt player, sáng lại. Không tải scene
func warp_player(player: Player, target_position: Vector3, facing: Vector3 = Vector3.ZERO) -> void:
	if _busy:
		return
	_busy = true
	await _fade.fade_out(fade_duration)
	if is_instance_valid(player):
		player.teleport(target_position, facing)
	await _fade.fade_in(fade_duration)
	_busy = false


## Vào checkpoint đã lưu; chưa có thì vào điểm start của khu đầu game. Dùng khi mở game và khi hồi sinh
func go_to_last_checkpoint() -> void:
	if GameState.has_checkpoint():
		change_zone(GameState.get_checkpoint_zone(), GameState.get_checkpoint_spawn_id())
	else:
		change_zone(START_ZONE)


## ZoneRoot gọi sau khi đã đặt player vào điểm xuất hiện
func notify_zone_ready() -> void:
	_zone_ready = true
	zone_ready.emit()


## ZoneRoot gọi khi khu tải xong để biết đặt player ở đâu; chỉ lấy được một lần
func consume_pending_spawn_id() -> StringName:
	var spawn_id := _pending_spawn_id
	_pending_spawn_id = &""
	return spawn_id
