@tool
class_name Boat
extends AnimatableBody3D
## Thuyền buồm chạy bằng gió theo tuyến cố định (Path3D), một chiều từ đầu tới cuối tuyến.
## Thổi từ phía sau buồm (lệch tối đa max_wind_angle_degrees): người đứng trên thuyền thổi thì chạy hết tuyến,
## thổi từ bờ thì trôi một đoạn. Thổi sai hướng thì buồm chỉ rung.
## Tới bến cuối: vị trí chỉ được lưu khi người chơi chạm một checkpoint mới (GameState.set_flag_on_checkpoint).
## Là vật đỡ di chuyển (AnimatableBody3D) nên chở được người chơi đứng trên boong.
## Hành vi theo FSM dạng node (objects/boat/states/).

@export var data: BoatData:
	set(value):
		data = value
		update_configuration_warnings()
## Tuyến thuyền chạy; điểm đầu là bến xuất phát, điểm cuối là bến tới
@export var route: Path3D:
	set(value):
		route = value
		update_configuration_warnings()
		if is_node_ready():
			_snap_to_route()
## Nước để nhấp nhô theo sóng; để trống thì đi đúng độ cao của tuyến
@export var water: Water
## ID duy nhất trong toàn game để nhớ thuyền đã tới bến (ví dụ "zone_1_wind.boat_harbor")
@export var persistent_id: StringName

## Tốc độ hiện tại dọc tuyến (m/s), các state đọc/ghi
var speed: float = 0.0

var _offset: float = 0.0
var _passengers: int = 0

@onready var state_machine: StateMachine = $StateMachine
@onready var _visual: BoatVisual = $BoatVisual
@onready var _wind_receiver: WindReceiverComponent = $WindReceiverComponent
@onready var _deck: Area3D = $Deck


func _ready() -> void:
	sync_to_physics = true
	if Engine.is_editor_hint():
		_snap_to_route()
		set_physics_process(false)
		return
	if data == null or route == null or route.curve == null:
		push_error("%s thiếu BoatData hoặc tuyến (route), thuyền bị tắt" % get_path())
		set_physics_process(false)
		return
	_visual.set_deployment(0.0)
	_wind_receiver.pushed.connect(_on_wind_pushed)
	_deck.body_entered.connect(_on_deck_body_entered)
	_deck.body_exited.connect(_on_deck_body_exited)
	if GameState.has_flag(persistent_id):
		# Đã tới bến và đã chạm checkpoint sau đó: xuất hiện luôn ở bến cuối
		_offset = _route_length()
		state_machine.initial_state = state_machine.get_node(NodePath(BoatState.ARRIVED)) as State
	_snap_to_route()


func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)
	_snap_to_route()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if data == null:
		warnings.append("Chưa gán BoatData: kéo resources/boat/boat_default.tres vào ô Data.")
	if route == null:
		warnings.append("Chưa gán Route: thêm một Path3D vẽ tuyến thuyền (điểm đầu = bến xuất phát) rồi kéo vào ô Route.")
	return warnings


## Đi tiếp dọc tuyến (m), không vượt quá bến cuối
func advance(distance: float) -> void:
	_offset = minf(_offset + distance, _route_length())


func get_remaining_distance() -> float:
	return _route_length() - _offset


func has_passenger() -> bool:
	return _passengers > 0


func raise_sail() -> void:
	_tween_sail(1.0, data.sail_raise_time)


func lower_sail() -> void:
	_tween_sail(0.0, data.sail_lower_time)


## Tới bến cuối: chờ checkpoint mới để lưu
func mark_arrived() -> void:
	GameState.set_flag_on_checkpoint(persistent_id)


## Hướng đi của tuyến tại vị trí hiện tại (mặt phẳng ngang)
func get_route_direction() -> Vector3:
	var curve := route.curve
	var ahead := minf(_offset + 0.1, _route_length())
	var behind := maxf(ahead - 0.2, 0.0)
	var direction := route.to_global(curve.sample_baked(ahead)) - route.to_global(curve.sample_baked(behind))
	direction.y = 0.0
	return direction.normalized() if not direction.is_zero_approx() else global_basis.z


func _route_length() -> float:
	return route.curve.get_baked_length() if route and route.curve else 0.0


func _snap_to_route() -> void:
	if route == null or route.curve == null or route.curve.point_count < 2:
		return
	var point := route.to_global(route.curve.sample_baked(_offset))
	if water and not Engine.is_editor_hint():
		point.y = water.get_height_at(point) + (data.float_height if data else 0.0)
	var forward := get_route_direction()
	global_transform = Transform3D(Basis.looking_at(-forward, Vector3.UP), point)


func _tween_sail(target: float, duration: float) -> void:
	_visual.animate_deployment(target, duration)


func _flutter_sail() -> void:
	_visual.flutter(data.flutter_time, sin(deg_to_rad(data.flutter_angle_degrees)))


func _on_wind_pushed(impulse: Vector3) -> void:
	var wind := Vector3(impulse.x, 0.0, impulse.z)
	if wind.is_zero_approx():
		return
	var tailwind := wind.normalized().dot(get_route_direction()) >= cos(deg_to_rad(data.max_wind_angle_degrees))
	if tailwind:
		(state_machine.current_state as BoatState).on_tailwind(has_passenger())
	else:
		_flutter_sail()


func _on_deck_body_entered(body: Node3D) -> void:
	if body is Player:
		_passengers += 1


func _on_deck_body_exited(body: Node3D) -> void:
	if body is Player:
		_passengers = maxi(_passengers - 1, 0)
