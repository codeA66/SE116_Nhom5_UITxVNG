extends Node
## Autoload "SceneManager": chuyển khu có màn mờ đen, ghi nhớ điểm xuất hiện cho khu mới,
## và hồi sinh tại checkpoint. Phải đứng sau GameState trong danh sách autoload.

signal zone_changed(zone_path: String)
## ZoneRoot của khu mới đã đặt player xong, có thể sáng màn hình
signal zone_ready

const FADE_LAYER_SCENE := preload("res://ui/transition/fade_layer.tscn")
## Scene không có ZoneRoot sẽ không báo zone_ready: chờ tối đa chừng này frame rồi vẫn sáng lại
const ZONE_READY_TIMEOUT_FRAMES := 30
## Khu đầu tiên của game: mở game lần đầu, hoặc chết khi chưa chạm checkpoint nào.
## Khai báo duy nhất ở đây; đổi khu đầu game chỉ sửa dòng này
const START_ZONE := "res://tests/test_game.tscn"

@export var fade_duration: float = 0.25

var _pending_spawn_id: StringName = &""
var _busy: bool = false
var _zone_ready: bool = false
var _fade: FadeLayer


func _ready() -> void:
	_fade = FADE_LAYER_SCENE.instantiate() as FadeLayer
	add_child(_fade)


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
	await _fade.fade_out(fade_duration)
	# Rời khu mà chưa chạm checkpoint: trạng thái chờ lưu (thuyền đã đi...) bị bỏ
	GameState.discard_pending_flags()
	_pending_spawn_id = spawn_id
	_zone_ready = false
	get_tree().change_scene_to_file(zone_path)
	# Scene mới được thay ở cuối frame; chờ ZoneRoot báo đã đặt player rồi mới sáng lại
	var waited_frames := 0
	while not _zone_ready and waited_frames < ZONE_READY_TIMEOUT_FRAMES:
		await get_tree().process_frame
		waited_frames += 1
	if not _zone_ready:
		push_warning("SceneManager: '%s' không có ZoneRoot báo sẵn sàng, vẫn sáng màn hình" % zone_path)
	await _fade.fade_in(fade_duration)
	_busy = false
	zone_changed.emit(zone_path)


## Hồi sinh tại checkpoint gần nhất (kể cả khi đang ở khu khác); chưa có checkpoint thì về khu đầu game
func respawn_at_checkpoint() -> void:
	go_to_last_checkpoint()


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
