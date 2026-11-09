class_name QuickItemUser
extends Node
## Gắn vào player lúc chạy (GameState gọi ensure khi Player vào cây; không sửa player.gd / player.tscn).
## Dùng vật phẩm đang chọn (GameState.get_selected_item) bằng phím use_item (T):
## - Vật phẩm có tầm (aim_range > 0): giữ T hiện vòng tầm + dấu dưới con trỏ (đi theo chuột), thả T thì dùng ở
##   chỗ dấu. Con trỏ ngoài tầm: dấu ở mép tầm theo hướng con trỏ. Mất điều khiển giữa chừng thì huỷ.
## - Không có tầm: bấm T là dùng ngay ở trước mặt.
## Không có chuột (headless): dấu ở trước mặt default_distance.
## Giữ trạng thái riêng của player cho từng vật phẩm (khối TNT đã đặt...): mỗi vật phẩm một Dictionary truyền vào use().
## Hiệu năng: nhận phím qua _unhandled_input; _process chỉ bật lúc đang giữ T để dấu đi theo chuột.

signal used(item: QuickItemData, target: Vector3)
signal aim_started(item: QuickItemData)
signal aim_cancelled

const NODE_NAME := &"QuickItemUser"
const ACTION := &"use_item"
## Lớp va chạm "world" (layer 1): tia con trỏ chạm sàn / tường
const WORLD_MASK := 1

var aiming: QuickItemData
## Chỗ sẽ dùng (đã giới hạn trong tầm, trên mặt sàn) của lần nhắm hiện tại
var target: Vector3

var _player: Player
## Id vật phẩm -> trạng thái riêng (khối TNT...)
var _states: Dictionary[StringName, Dictionary] = {}
## Id vật phẩm -> mốc (ms) được dùng lại
var _ready_at: Dictionary[StringName, int] = {}
## Id vật phẩm -> hình nhắm (tạo một lần, dùng lại)
var _indicators: Dictionary[StringName, AimIndicator] = {}


static func ensure(player: Player) -> QuickItemUser:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return null
	var user := player.get_node_or_null(NodePath(NODE_NAME)) as QuickItemUser
	if user == null:
		user = QuickItemUser.new()
		user.name = NODE_NAME
		player.add_child(user)
	return user


func _ready() -> void:
	_player = get_parent() as Player
	set_process(false)
	set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(ACTION):
		if begin_aim():
			get_viewport().set_input_as_handled()
	elif event.is_action_released(ACTION) and aiming != null:
		release()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if aiming == null:
		set_process(false)
		return
	if not can_use(aiming):
		cancel_aim()
		return
	_update_target()


## Bắt đầu nhắm vật phẩm đang chọn (không có tầm thì dùng ngay); true = đã nhận phím
func begin_aim() -> bool:
	var item := GameState.get_selected_item()
	if not can_use(item):
		return false
	if item.aim_range <= 0.0:
		return _use(item, item.resolve_target(_player, item.default_target(_player), _exclude(item)))
	aiming = item
	_update_target()
	set_process(true)
	aim_started.emit(item)
	return true


## Thả phím: dùng ở chỗ dấu; true = đã dùng
func release() -> bool:
	var item := aiming
	if item == null:
		return false
	_update_target()
	_end_aim()
	if not can_use(item):
		return false
	return _use(item, target)


func cancel_aim() -> void:
	if aiming == null:
		return
	_end_aim()
	aim_cancelled.emit()


## Dùng được không: có trong túi, đang điều khiển được, không mở menu / hộp thoại, hết hồi chiêu
func can_use(item: QuickItemData) -> bool:
	if item == null or not is_instance_valid(_player) or not _player.controls_enabled:
		return false
	if _player.combat_locked() or _player.health.is_dead() or GameState.get_item_count(item) <= 0:
		return false
	# Đang mở menu / hộp thoại (một Control giữ focus): phím dành cho giao diện
	if get_viewport().gui_get_focus_owner() != null:
		return false
	return Time.get_ticks_msec() >= _ready_at.get(item.id, 0)


## Trạng thái riêng của vật phẩm item_id (test đọc); rỗng nếu chưa dùng lần nào
func get_state(item_id: StringName) -> Dictionary:
	return _states.get(item_id, {})


func get_indicator(item_id: StringName) -> AimIndicator:
	return _indicators.get(item_id)


func _use(item: QuickItemData, at: Vector3) -> bool:
	if not item.use(_player, _state_of(item), at):
		return false
	_ready_at[item.id] = Time.get_ticks_msec() + int(item.cooldown * 1000.0)
	used.emit(item, at)
	return true


func _update_target() -> void:
	var raw := _cursor_point()
	target = aiming.resolve_target(_player, raw, _exclude(aiming))
	var indicator := _indicator_of(aiming)
	if indicator:
		indicator.aim_at(_player.global_position, aiming.aim_range, target)


func _end_aim() -> void:
	var indicator := _indicators.get(aiming.id) as AimIndicator
	if indicator:
		indicator.hide()
	aiming = null
	set_process(false)


## Điểm dưới con trỏ: tia từ camera qua chuột chạm thế giới; không chạm thì cắt mặt phẳng ngang ở chân player.
## Headless (không có chuột): trước mặt default_distance
func _cursor_point() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if DisplayServer.get_name() == "headless" or camera == null:
		return aiming.default_target(_player)
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(from, from + normal * 200.0, WORLD_MASK)
	query.exclude = _exclude(aiming)
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position
	var on_plane: Variant = Plane(Vector3.UP, _player.global_position.y).intersects_ray(from, normal)
	return on_plane as Vector3 if on_plane != null else aiming.default_target(_player)


func _exclude(item: QuickItemData) -> Array[RID]:
	var result: Array[RID] = [_player.get_rid()]
	result.append_array(item.get_probe_exclude(_state_of(item)))
	return result


func _state_of(item: QuickItemData) -> Dictionary:
	if not _states.has(item.id):
		_states[item.id] = {}
	return _states[item.id]


func _indicator_of(item: QuickItemData) -> AimIndicator:
	if _indicators.has(item.id):
		return _indicators[item.id]
	if item.aim_indicator == null:
		return null
	var indicator := item.aim_indicator.instantiate() as AimIndicator
	add_child(indicator)
	_indicators[item.id] = indicator
	return indicator
