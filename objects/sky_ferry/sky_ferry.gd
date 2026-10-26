class_name SkyFerry
extends AnimatableBody3D
## Thuyền bay chở khách: ẩn ngoài trời cho tới khi cơ quan gọi (call_source) bật, bay theo approach_route tới bến,
## đậu chờ; người chơi đứng trên boong đủ lâu thì tự cất cánh, chở theo travel_route tới bến mới và đậu lại.
## Điểm cuối approach_route trùng điểm đầu travel_route (cùng hướng) để không xoay giật khi cất cánh.
## Mỗi thuyền chỉ nghe đúng cơ quan được gán: map có nhiều cặp trụ - thuyền không lẫn nhau.
## Hành vi theo FSM dạng node (objects/sky_ferry/states/).

## Vừa được gọi / vừa cập bến chờ / vừa cất cánh / vừa tới bến mới
signal called
signal docked
signal departed
signal arrived

@export var data: SkyFerryData
## Cơ quan gọi thuyền: node có signal "activated" và hàm is_active()
@export var call_source: Node
## Đường bay tới bến (điểm cuối = chỗ đậu chờ khách)
@export var approach_route: Path3D
## Đường chở khách (điểm đầu = chỗ đậu chờ khách, điểm cuối = bến mới)
@export var travel_route: Path3D
## Chặn khe bến khi thuyền không đậu ở đó (vật có va chạm và hình lan can). Để trống = không chặn
@export var berth_blocker: CollisionObject3D

## Tốc độ hiện tại dọc đường bay (m/s), các state đọc/ghi
var speed: float = 0.0
var route: Path3D
var offset: float = 0.0

var _bob_time: float = 0.0
## Hướng mũi hiện tại (mặt phẳng ngang), xoay dần về hướng đường bay
var _heading: Vector3 = Vector3.FORWARD
var _passengers: Array[Player] = []

@onready var state_machine: StateMachine = $StateMachine
@onready var _hull: CollisionShape3D = $Hull
@onready var _deck: Area3D = $Deck
@onready var _model: Node3D = $Model
@onready var _animator: AnimationPlayer = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _ready() -> void:
	sync_to_physics = true
	if data == null or approach_route == null or travel_route == null:
		push_error("%s thiếu SkyFerryData hoặc đường bay, thuyền bị tắt" % get_path())
		set_physics_process(false)
		return
	_deck.body_entered.connect(_on_deck_entered)
	_deck.body_exited.connect(_on_deck_exited)
	if call_source and call_source.has_signal(&"activated"):
		call_source.connect(&"activated", _on_called)
	else:
		push_error("%s: cơ quan gọi %s không có signal activated" % [get_path(), call_source])


func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)


## Đặt thuyền lên đường bay ở vị trí at (m), mũi theo hướng bay; bob cộng thêm độ cao nhấp nhô.
## turn_delta > 0: mũi xoay dần về hướng mới (không giật ở chỗ cong); = 0: đặt thẳng hướng (lúc bắt đầu đường bay)
func follow(on_route: Path3D, at: float, bob: float = 0.0, turn_delta: float = 0.0) -> void:
	route = on_route
	offset = clampf(at, 0.0, route_length())
	var curve := route.curve
	var point := route.to_global(curve.sample_baked(offset))
	var ahead := minf(offset + 0.1, route_length())
	var behind := maxf(ahead - 0.2, 0.0)
	var forward := route.to_global(curve.sample_baked(ahead)) - route.to_global(curve.sample_baked(behind))
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = _heading
	forward = forward.normalized()
	if turn_delta > 0.0 and _heading.length_squared() > 0.0:
		# Nội suy góc yaw thay vì Vector3.slerp: slerp tự tính trục xoay, hai hướng gần trùng/ngược nhau cho trục
		# lệch chuẩn (báo lỗi mỗi frame). Mũi thuyền chỉ xoay quanh trục đứng nên lerp_angle là đủ
		var yaw := lerp_angle(atan2(_heading.x, _heading.z), atan2(forward.x, forward.z), 1.0 - exp(-data.turn_response * turn_delta))
		_heading = Vector3(sin(yaw), 0.0, cos(yaw))
	else:
		_heading = forward
	global_transform = Transform3D(Basis.looking_at(-_heading, Vector3.UP), point + Vector3(0, bob, 0))


func route_length() -> float:
	return route.curve.get_baked_length() if route and route.curve else 0.0


func remaining() -> float:
	return route_length() - offset


## Tăng / giảm tốc về max_speed, chậm dần khi gần cuối đường; trả về true khi đã tới cuối
func fly(max_speed: float, delta: float) -> bool:
	var target := max_speed
	if remaining() < data.slow_distance:
		target = maxf(max_speed * remaining() / data.slow_distance, data.min_speed)
	speed = move_toward(speed, target, data.acceleration * delta)
	follow(route, offset + speed * delta, 0.0, delta)
	return remaining() <= 0.01


## Nhấp nhô tại chỗ (đậu bến)
func hover(delta: float) -> void:
	_bob_time += delta
	follow(route, offset, sin(_bob_time * data.bob_speed) * data.bob_amplitude, delta)


func set_present(present: bool) -> void:
	visible = present
	_hull.set_deferred(&"disabled", not present)
	_deck.set_deferred(&"monitoring", present)
	if _animator and _animator.has_animation(&"FlyLoop"):
		if present:
			_animator.play(&"FlyLoop")
		else:
			_animator.stop()


## Mở khe bến khi thuyền đậu đúng chỗ; đóng lại khi thuyền vắng (không ai bước hụt ra trời)
func set_berth_open(open: bool) -> void:
	if berth_blocker == null:
		return
	berth_blocker.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT)
	berth_blocker.visible = not open


## Có người chơi đứng vững trên boong
func has_grounded_passenger() -> bool:
	for p in _passengers:
		if is_instance_valid(p) and p.is_on_floor():
			return true
	return false


## State gọi khi chuyển trạng thái: signal phát từ chính class khai báo nó
func notify_called() -> void:
	called.emit()


func notify_docked() -> void:
	docked.emit()


func notify_departed() -> void:
	departed.emit()


func notify_arrived() -> void:
	arrived.emit()


func _on_called() -> void:
	(state_machine.current_state as SkyFerryState).on_called()


func _on_deck_entered(body: Node3D) -> void:
	if body is Player and not _passengers.has(body):
		_passengers.append(body as Player)


func _on_deck_exited(body: Node3D) -> void:
	if body is Player:
		_passengers.erase(body as Player)
