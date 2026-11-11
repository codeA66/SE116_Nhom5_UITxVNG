extends SpiderSkill
## Nhảy vồ: gồng (nháy báo trước, quay theo player) → chốt chỗ đáp ở cuối pha gồng rồi bay theo đường parabol tới đó
## → đáp xuống gây sát thương vùng nhỏ (FireSpider.land_impact) → hồi (khoảng hở cho player phản công).
## Player chạy khỏi chỗ đã chốt thì nhảy hụt. Bị đánh / thổi gió giữa chừng thì state khác chen vào: exit() hủy báo trước,
## đã tính hồi chiêu. Mọi mốc thời gian lấy từ FireSpiderData.

enum Phase { WINDUP, AIR, LAND }

const ANIM_WINDUP := &"Pounce_Windup"
const ANIM_AIR := &"Pounce_Air"
const ANIM_LAND := &"Pounce_Land"
## Hết giờ bay mà chưa chạm đất (rơi xuống hố...) thì coi như đáp, thêm chừng này (s)
const AIR_GRACE := 0.35
## Phải bay ít nhất chừng này (s) mới tính là đáp: tránh nhận nhầm khung đầu còn đang chạm đất
const MIN_AIR_TIME := 0.1

var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0


func can_use() -> bool:
	return spider.spider_data.pounce_attack != null and super()


func enter(_previous: StringName) -> void:
	_phase = Phase.WINDUP
	_elapsed = 0.0
	enemy.face_instantly(enemy.direction_to_target())
	enemy.velocity.x = 0.0
	enemy.velocity.z = 0.0
	enemy.set_telegraph(true)
	enemy.play_action(ANIM_WINDUP, _clip_speed(ANIM_WINDUP, spider.spider_data.pounce_windup_time))


func exit() -> void:
	enemy.set_telegraph(false)
	start_cooldown()


func physics_update(delta: float) -> void:
	_elapsed += delta
	if _phase == Phase.WINDUP:
		_update_windup(delta)
	elif _phase == Phase.AIR:
		_update_air(delta)
	else:
		_update_land(delta)


func _update_windup(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.move_toward_direction(Vector3.ZERO, delta)
	enemy.face_direction(enemy.direction_to_target(), delta)
	if _elapsed >= spider.spider_data.pounce_windup_time:
		_start_air()


func _start_air() -> void:
	var data: FireSpiderData = spider.spider_data
	_phase = Phase.AIR
	_elapsed = 0.0
	# Chốt chỗ đáp lúc này; không vượt quá tầm tối đa (player đứng sát / ra xa quá thì cắt bớt)
	var offset: Vector3 = enemy.direction_to_target() * minf(enemy.distance_to_target(), data.pounce_max_range)
	enemy.velocity.x = offset.x / data.pounce_air_time
	enemy.velocity.z = offset.z / data.pounce_air_time
	# Parabol đối xứng: lên rồi xuống đúng pounce_air_time (không dùng hệ số rơi nhanh của apply_gravity)
	enemy.velocity.y = 0.5 * enemy.gravity * data.pounce_air_time
	enemy.face_instantly(offset)
	enemy.set_telegraph(false)
	enemy.play_action(ANIM_AIR)


func _update_air(delta: float) -> void:
	enemy.velocity.y -= enemy.gravity * delta
	var data: FireSpiderData = spider.spider_data
	var landed: bool = _elapsed >= MIN_AIR_TIME and enemy.is_on_floor()
	if landed or _elapsed >= data.pounce_air_time + AIR_GRACE:
		_land()


func _land() -> void:
	_phase = Phase.LAND
	_elapsed = 0.0
	enemy.velocity.x = 0.0
	enemy.velocity.z = 0.0
	spider.land_impact()
	enemy.play_action(ANIM_LAND, _clip_speed(ANIM_LAND, spider.spider_data.pounce_land_time))


func _update_land(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.move_toward_direction(Vector3.ZERO, delta)
	if _elapsed >= spider.spider_data.pounce_land_time:
		state_machine.transition_to(enemy.chase_state if enemy.has_target() else IDLE)


func _min_range() -> float:
	return spider.spider_data.pounce_min_range


func _max_range() -> float:
	return spider.spider_data.pounce_max_range


func _cooldown_time() -> float:
	return spider.spider_data.pounce_cooldown


## Clip chạy khớp thời gian của pha (0 nếu model chưa có clip: giữ tốc độ 1)
func _clip_speed(clip: StringName, time: float) -> float:
	var length: float = spider.get_animation_length(clip)
	return length / time if length > 0.0 and time > 0.0 else 1.0
