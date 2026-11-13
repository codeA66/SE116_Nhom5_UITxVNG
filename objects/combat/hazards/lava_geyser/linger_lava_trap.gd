class_name LingerLavaTrap
extends Area3D
## Bẫy lửa trên mặt cầu (qua LavaGeyser ở chế độ kích hoạt), hai chế độ:
## - follow_interval > 0: vừa chạm vào vùng là cảnh báo + phun ngay dưới chân, rồi cứ follow_interval giây lại phun
##   vào chỗ player đang đứng (phải chạy liên tục, né vòng cảnh báo).
## - follow_interval = 0: "đứng lâu là bị phun": đứng một chỗ quá linger_time giây thì phụt lên đúng chỗ đó.
## Đặt shape phủ mặt cầu.
## Hiệu năng: theo dõi player bằng body_entered/exited, chỉ chạy _physics_process khi player đang trong vùng;
## các mạch dung nham tạo sẵn một lần (pool), không instantiate khi chơi.

signal geyser_triggered(at: Vector3)

@export var geyser_scene: PackedScene = preload("res://objects/combat/hazards/lava_geyser/lava_geyser.tscn")
## Đứng trong bán kính này (m, mặt phẳng XZ) quanh điểm neo được tính là "đứng một chỗ"
@export_range(0.2, 5.0, 0.05) var stand_radius: float = 1.2
## Thời gian đứng một chỗ trước khi kích hoạt (giây); sau đó còn thêm thời gian cảnh báo của mạch
@export_range(0.1, 10.0, 0.05) var linger_time: float = 1.0
## > 0: phun theo nhịp vào chỗ player (lần đầu ngay khi bước vào), không chờ đứng yên
@export_range(0.0, 10.0, 0.05) var follow_interval: float = 0.0
## Chế độ follow: trễ trước lần phun đầu sau khi bước vào (giây). 0 = phun ngay
@export_range(0.0, 10.0, 0.05) var first_delay: float = 0.0
## Ghi đè thời gian cảnh báo của các mạch trong bẫy này (giây). 0 = giữ mặc định của geyser_scene
@export_range(0.0, 5.0, 0.05) var geyser_warning_time: float = 0.0
## Số mạch tạo sẵn, đủ cho các lượt chồng nhau
@export_range(1, 8) var pool_size: int = 3
## Độ cao mặt sàn (tọa độ thế giới) nơi mạch phụt lên
@export var floor_y: float = 0.0

## Kiểu CharacterBody3D (không dùng Player) để script dựng map chạy -s không phụ thuộc autoload; mask chỉ có layer player
var _player: CharacterBody3D
var _anchor: Vector2
var _timer: float = 0.0
var _pool: Array[LavaGeyser] = []


func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	for i: int in range(pool_size):
		var g: LavaGeyser = geyser_scene.instantiate() as LavaGeyser
		g.auto_cycle = false
		if geyser_warning_time > 0.0:
			g.warning_time = geyser_warning_time
		g.name = "Geyser%d" % (i + 1)
		add_child(g)
		_pool.append(g)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_stop()
		return
	var pos: Vector2 = Vector2(_player.global_position.x, _player.global_position.z)
	if follow_interval > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			_timer = follow_interval
			_erupt(pos)
		return
	if pos.distance_to(_anchor) > stand_radius:
		_anchor = pos
		_timer = 0.0
		return
	_timer += delta
	if _timer < linger_time:
		return
	_erupt(_anchor)
	# Đứng tiếp tại chỗ thì lượt sau tính lại từ đầu
	_timer = 0.0


func _erupt(at_xz: Vector2) -> void:
	for g: LavaGeyser in _pool:
		if not g.busy:
			var at: Vector3 = Vector3(at_xz.x, floor_y, at_xz.y)
			g.trigger(at)
			geyser_triggered.emit(at)
			return


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player = body as CharacterBody3D
		_anchor = Vector2(body.global_position.x, body.global_position.z)
		# Chế độ follow đếm ngược tới lần phun: first_delay cho người chơi kịp nhìn thấy bẫy
		_timer = first_delay if follow_interval > 0.0 else 0.0
		set_physics_process(true)


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_stop()


func _stop() -> void:
	_player = null
	set_physics_process(false)
