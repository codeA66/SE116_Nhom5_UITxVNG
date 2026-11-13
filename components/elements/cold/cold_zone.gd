class_name ColdZone
extends Area3D
## Vùng lạnh (hang băng của sinh vật khác trong map Lửa, ý tưởng Thịnh): player ở trong mà không được sưởi thì
## bị lạnh: chậm đi (slow_scale) và cứ damage_interval giây mất 1 máu, nhưng không xuống dưới min_health (không chết vì lạnh).
## Được sưởi khi: đứng trong WarmZone (lửa trại), cầm đuốc đang cháy, hoặc kiếm đang ghép Lửa.
## Không sửa player.gd: làm chậm bằng cách tạm thay MovementStats của player bằng bản sao chậm hơn, ra / được sưởi thì trả lại.
## Hiệu năng: _physics_process chỉ chạy khi player ở trong vùng (theo dõi bằng signal vào / ra).

signal chilled_changed(chilled: bool)
signal cold_tick(health_left: int)

## Lửa trại / chỗ ấm trong vùng
@export var warm_zones: Array[WarmZone] = []
## Bao lâu mất 1 máu khi bị lạnh (s)
@export_range(0.1, 60.0, 0.1) var damage_interval: float = 4.0
## Lạnh không làm máu xuống dưới mức này
@export_range(1, 10) var min_health: int = 1
## Tốc độ chạy khi bị lạnh so với bình thường
@export_range(0.05, 1.0, 0.01) var slow_scale: float = 0.6

var is_chilled: bool = false

var _player: Player
var _timer: float = 0.0
var _normal_movement: MovementStats
var _slow_movement: MovementStats


func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_leave()
		return
	if is_warm(_player):
		_set_chilled(false)
		_timer = 0.0
		return
	_set_chilled(true)
	_timer += delta
	if _timer < damage_interval:
		return
	_timer -= damage_interval
	var health := _player.health
	if health.current_health > min_health:
		health.take_damage(1)
		cold_tick.emit(health.current_health)


## Player đang được sưởi (lửa trại, đuốc cháy, kiếm Lửa)
func is_warm(player: Player) -> bool:
	for zone: WarmZone in warm_zones:
		if zone and zone.has_player():
			return true
	var torch := HandTorch.find_on(player)
	if torch and torch.is_lit:
		return true
	var sword_element := GameState.get_fused_element(WeaponData.Slot.SWORD)
	return sword_element != null and sword_element.id == &"fire"


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_player = body as Player
		_timer = 0.0
		set_physics_process(true)


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_leave()


func _leave() -> void:
	_set_chilled(false)
	_player = null
	set_physics_process(false)


## Bật / tắt lạnh: thay MovementStats của player bằng bản chậm (tạo một lần), trả lại bản gốc khi hết lạnh
func _set_chilled(chilled: bool) -> void:
	if chilled == is_chilled:
		return
	is_chilled = chilled
	if is_instance_valid(_player):
		if chilled:
			_normal_movement = _player.movement
			if _slow_movement == null:
				_slow_movement = _normal_movement.duplicate() as MovementStats
				_slow_movement.max_speed = _normal_movement.max_speed * slow_scale
			_player.movement = _slow_movement
		elif _normal_movement:
			_player.movement = _normal_movement
	chilled_changed.emit(chilled)
