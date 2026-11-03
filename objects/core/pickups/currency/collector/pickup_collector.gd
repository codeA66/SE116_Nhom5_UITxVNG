class_name PickupCollector
extends Node
## Gắn trên người chơi: nhận lệnh rơi tiền từ quái chết (LootDropComponent tìm qua group), lấy viên rơi từ object pool
## theo scene của từng loại tiền (CurrencyData.pickup_scene), cho bay về target; viên chạm người thì cộng tiền rồi nhả về pool.
## Rơi nhiều thì gom thành tối đa max_visual_pickups viên, mỗi viên mang nhiều tiền hơn: tổng tiền vẫn đúng.
## Thêm loại tiền mới không sửa file này.

## Group để quái tìm người nhặt lúc chết (chỉ một người chơi trong khu)
const GROUP := &"pickup_collector"

## Mỗi lần nhặt một viên (âm thanh / hiệu ứng nghe)
signal pickup_collected(currency: CurrencyData, value: int)

## Người nhặt (thường là chính người chơi)
@export var target: Node3D
## Số viên tối đa bay ra cho một lần rơi của một loại tiền
@export_range(1, 64) var max_visual_pickups: int = 12
## Loại tiền tạo sẵn pool lúc vào khu (không instantiate giữa trận); loại khác vẫn rơi được, pool tạo lúc cần
@export var prewarm_currencies: Array[CurrencyData] = []
## Số viên tạo sẵn cho mỗi loại (thiếu thì pool tạo thêm)
@export_range(0, 64) var pool_size: int = 12
## Âm thanh nhặt (để trống nếu chưa có file)
@export var pickup_sound: AudioStream

var _pools: Dictionary[PackedScene, ObjectPool] = {}
var _sound: AudioStreamPlayer


func _ready() -> void:
	add_to_group(GROUP)
	for kind: CurrencyData in prewarm_currencies:
		if kind and kind.pickup_scene:
			_pool_for(kind.pickup_scene)
	if pickup_sound:
		_sound = AudioStreamPlayer.new()
		_sound.stream = pickup_sound
		add_child(_sound)


## Rơi amount tiền loại currency ở origin: chia đều vào tối đa max_visual_pickups viên
func spawn(origin: Vector3, currency: CurrencyData, amount: int) -> void:
	if currency == null or amount <= 0:
		return
	if currency.pickup_scene == null:
		push_warning("PickupCollector: '%s' chưa có pickup_scene, cộng thẳng không có viên bay" % currency.id)
		GameState.add_currency(currency.id, amount)
		return
	var pool := _pool_for(currency.pickup_scene)
	var count := mini(amount, max_visual_pickups)
	@warning_ignore("integer_division")
	var each := amount / count
	var extra := amount % count
	for i in count:
		var pickup := pool.acquire() as CurrencyPickup
		pickup.launch(origin, target, currency, each + (1 if i < extra else 0))


## Tổng số viên đang bay (test / debug)
func get_active_count() -> int:
	var total := 0
	for pool: ObjectPool in _pools.values():
		total += pool.get_active_count()
	return total


func _pool_for(scene: PackedScene) -> ObjectPool:
	if _pools.has(scene):
		return _pools[scene]
	var pool := ObjectPool.new()
	pool.name = "Pool_%d" % _pools.size()
	pool.scene = scene
	pool.initial_size = pool_size
	pool.configure_instance = func(node: Node) -> void:
		(node as CurrencyPickup).collected.connect(_on_collected.bind(pool))
	_pools[scene] = pool
	add_child(pool)
	return pool


func _on_collected(pickup: CurrencyPickup, pool: ObjectPool) -> void:
	if pickup.currency:
		GameState.add_currency(pickup.currency.id, pickup.value)
		pickup_collected.emit(pickup.currency, pickup.value)
	if _sound:
		_sound.play()
	pool.release(pickup)
