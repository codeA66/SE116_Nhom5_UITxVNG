@tool
class_name LavaZone
extends Area3D
## Vùng dung nham đi tới được (cầu ngập, vũng dung nham trên sàn): bước vào thì mất enter_damage máu (đòn FIRE)
## và bị đốt (BurnableComponent của body, thời gian / nhịp theo BurnData của body). Đứng trong vùng thì lửa
## được làm mới mỗi refresh_interval giây nên cháy mãi tới khi bước ra; ra rồi cháy nốt duration của BurnData.
## Không giết ngay. Body không có hurtbox / burnable thì bỏ qua phần đó.
## Body đã có kỹ năng immunity_ability (giày dung nham: body.has_ability) thì không bị gì.
## Hiệu năng: chỉ nghe body_entered / exited; Timer làm mới lửa chỉ chạy khi có body bên trong.

## Kích thước vùng (m), hộp đặt giữa tâm node
@export var size: Vector3 = Vector3(4.0, 2.0, 4.0):
	set(value):
		size = value.max(Vector3.ONE * 0.1)
		_apply_size()
## Máu mất ngay lúc bước vào (luật game: 1)
@export var enter_damage: int = 1
## Khoảng làm mới lửa khi đứng trong vùng (s); nên nhỏ hơn duration của BurnData
@export_range(0.1, 10.0, 0.05) var refresh_interval: float = 0.5
## Kỹ năng / vật phẩm giúp miễn nhiễm (đọc qua body.has_ability). Để trống = ai cũng bị đốt
@export var immunity_ability: StringName = &"lava_boots"

var _inside: Array[Node3D] = []

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _timer: Timer = $RefreshTimer


func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return
	monitorable = false
	_timer.wait_time = refresh_interval
	_timer.timeout.connect(_refresh)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _apply_size() -> void:
	if not is_node_ready():
		return
	(_shape.shape as BoxShape3D).size = size


func _on_body_entered(body: Node3D) -> void:
	_inside.append(body)
	if _is_immune(body):
		return
	var hurtbox: HurtboxComponent = _find(body, &"HurtboxComponent") as HurtboxComponent
	if hurtbox and enter_damage > 0:
		var info: DamageInfo = DamageInfo.new(enter_damage, DamageInfo.Type.FIRE, Vector3.ZERO, self)
		info.staggers = false
		hurtbox.receive_hit(info)
	_ignite(body)
	if _timer.is_stopped():
		_timer.start()


func _on_body_exited(body: Node3D) -> void:
	_inside.erase(body)
	if _inside.is_empty():
		_timer.stop()


func _refresh() -> void:
	for body: Node3D in _inside:
		if is_instance_valid(body):
			_ignite(body)


func _is_immune(body: Node3D) -> bool:
	return not immunity_ability.is_empty() and body.has_method(&"has_ability") and bool(body.call(&"has_ability", immunity_ability))


func _ignite(body: Node3D) -> void:
	if _is_immune(body):
		return
	var burnable: BurnableComponent = _find(body, &"BurnableComponent") as BurnableComponent
	if burnable:
		burnable.ignite(self)


func _find(body: Node3D, node_name: StringName) -> Node:
	return body.get_node_or_null(NodePath(String(node_name)))
