class_name PickupCollector
extends Node
## Gắn trên người chơi: nhận lệnh rơi tiền từ quái chết (LootDropComponent tìm qua group), lấy viên rơi từ object pool
## theo scene của từng loại tiền (CurrencyData.pickup_scene), cho bay về target; viên chạm người thì cộng tiền rồi nhả về pool.
## Rơi nhiều thì gom thành tối đa max_visual_pickups viên, mỗi viên mang nhiều tiền hơn: tổng tiền vẫn đúng.
## Hiệu ứng rơi / nhặt (CurrencyData.drop_vfx_scene / collect_vfx_scene) cũng lấy từ pool; chớp lúc nhặt có giới hạn
## tần suất để nhiều viên về cùng lúc không thành mảng chói. Thêm loại tiền mới không sửa file này.

## Group để quái tìm người nhặt lúc chết (chỉ một người chơi trong khu)
const GROUP := &"pickup_collector"

## Mỗi lần nhặt một viên (âm thanh / hiệu ứng nghe)
signal pickup_collected(currency: CurrencyData, value: int)
## Vừa phát chớp sáng lúc nhặt (test / âm thanh)
signal collect_vfx_played

## Người nhặt (thường là chính người chơi)
@export var target: Node3D
## Số viên tối đa bay ra cho một lần rơi; 1 = kiểu Death's Door (quái chết rơi 1 hạt bay về người, mang toàn bộ số tiền)
@export_range(1, 64) var max_visual_pickups: int = 1
## Loại tiền tạo sẵn pool lúc vào khu (không instantiate giữa trận); loại khác vẫn rơi được, pool tạo lúc cần
@export var prewarm_currencies: Array[CurrencyData] = []
## Số viên tạo sẵn cho mỗi loại (thiếu thì pool tạo thêm)
@export_range(0, 64) var pool_size: int = 3
## Số hiệu ứng rơi / nhặt tạo sẵn cho mỗi loại
@export_range(0, 16) var vfx_pool_size: int = 3
## Hai chớp sáng lúc nhặt cách nhau ít nhất bấy nhiêu giây
@export_range(0.0, 1.0, 0.01) var collect_vfx_interval: float = 0.08
## Chớp sáng lúc nhặt đặt ở ngực người nhặt (cao hơn chân bấy nhiêu)
@export var collect_vfx_height: float = 0.8
## Âm thanh nhặt (để trống nếu chưa có file)
@export var pickup_sound: AudioStream

var _pools: Dictionary[PackedScene, ObjectPool] = {}
var _drop_vfx_pools: Array[ObjectPool] = []
var _collect_vfx_pools: Array[ObjectPool] = []
var _last_collect_vfx_ms: int = -1000000
var _sound: AudioStreamPlayer


func _ready() -> void:
	add_to_group(GROUP)
	for kind: CurrencyData in prewarm_currencies:
		if kind == null:
			continue
		if kind.pickup_scene:
			_pickup_pool(kind.pickup_scene)
		if kind.drop_vfx_scene:
			_vfx_pool(kind.drop_vfx_scene, _drop_vfx_pools)
		if kind.collect_vfx_scene:
			_vfx_pool(kind.collect_vfx_scene, _collect_vfx_pools)
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
	if currency.drop_vfx_scene:
		(_vfx_pool(currency.drop_vfx_scene, _drop_vfx_pools).acquire() as PickupVfx).play(origin)
	var pool := _pickup_pool(currency.pickup_scene)
	var count := mini(amount, max_visual_pickups)
	@warning_ignore("integer_division")
	var each := amount / count
	var extra := amount % count
	for i in count:
		var pickup := pool.acquire() as CurrencyPickup
		pickup.launch(origin, target, currency, each + (1 if i < extra else 0))


## Tổng số viên đang bay (test / debug)
func get_active_count() -> int:
	return _active_in(_pools.values())


## Số hiệu ứng rơi / nhặt đang chạy (test / debug)
func get_active_drop_vfx_count() -> int:
	return _active_in(_drop_vfx_pools)


func get_active_collect_vfx_count() -> int:
	return _active_in(_collect_vfx_pools)


func _active_in(pools: Array) -> int:
	var total := 0
	for pool: ObjectPool in pools:
		total += pool.get_active_count()
	return total


func _pickup_pool(scene: PackedScene) -> ObjectPool:
	if _pools.has(scene):
		return _pools[scene]
	var pool := _make_pool(scene, pool_size)
	pool.configure_instance = func(node: Node) -> void:
		(node as CurrencyPickup).collected.connect(_on_collected.bind(pool))
	_pools[scene] = pool
	add_child(pool)
	return pool


## Pool hiệu ứng theo scene; list = nhóm (rơi / nhặt) để đếm riêng
func _vfx_pool(scene: PackedScene, list: Array[ObjectPool]) -> ObjectPool:
	for pool in list:
		if pool.scene == scene:
			return pool
	var pool := _make_pool(scene, vfx_pool_size)
	pool.configure_instance = func(node: Node) -> void:
		(node as PickupVfx).finished.connect(pool.release.bind(node))
	list.append(pool)
	add_child(pool)
	return pool


func _make_pool(scene: PackedScene, size: int) -> ObjectPool:
	var pool := ObjectPool.new()
	pool.name = "Pool_%s" % scene.resource_path.get_file().get_basename()
	pool.scene = scene
	pool.initial_size = size
	return pool


func _on_collected(pickup: CurrencyPickup, pool: ObjectPool) -> void:
	var kind := pickup.currency
	if kind:
		GameState.add_currency(kind.id, pickup.value)
		pickup_collected.emit(kind, pickup.value)
		_play_collect_vfx(kind)
	if _sound:
		_sound.play()
	pool.release(pickup)


func _play_collect_vfx(kind: CurrencyData) -> void:
	var now := Time.get_ticks_msec()
	if kind.collect_vfx_scene == null or not is_instance_valid(target) or now - _last_collect_vfx_ms < int(collect_vfx_interval * 1000.0):
		return
	_last_collect_vfx_ms = now
	(_vfx_pool(kind.collect_vfx_scene, _collect_vfx_pools).acquire() as PickupVfx).play(target.global_position + Vector3.UP * collect_vfx_height)
	collect_vfx_played.emit()
