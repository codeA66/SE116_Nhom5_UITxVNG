extends FireToadState
## Skill 2, Rút ra ngoài sân: gầm gọi nhện canh lên các góc ngoài sân (nhện bắn tơ làm player chậm + khoá lộn, phải
## đốt tơ bằng lửa hoặc bắn cung hạ nhện), nhảy ra một bệ ngoài sân, đứng đó bắn cầu lửa thẳng về player và nhảy đổi
## bệ (mỗi loạt xoè quạt, nhắm đón đầu); hết retreat_duration thì nhảy về giữa sân và nhện còn sống rút đi. Lúc đứng ngoài, player bắn cung trúng được.

## Gồng gọi nhện trước khi nhảy ra (s)
@export_range(0.0, 3.0, 0.05) var summon_windup: float = 0.6

var _rng := RandomNumberGenerator.new()
var _platform_index: int = -1


func _ready() -> void:
	super()
	_rng.randomize()


func _run(id: int) -> void:
	var skills := toad.skills()
	var data := toad.data
	toad.face_player()
	toad.play_clip(&"Web_Spray")
	toad.vfx.charge_web(summon_windup)
	await wait(summon_windup)
	if not still_running(id):
		return
	toad.summon_sentinels(skills.sentinel_count, skills.sentinel_stagger)
	if toad.outer_platforms.is_empty():
		push_warning("%s: chưa gán outer_platforms, bỏ phần nhảy ra ngoài" % toad.name)
		finish(id)
		return
	await _leap_to_platform(_next_platform(), data)
	var elapsed := 0.0
	var shot_clock := 0.0
	var hop_clock := 0.0
	while elapsed < skills.retreat_duration:
		if not still_running(id):
			return
		toad.face_player()
		var delta := toad.get_physics_process_delta_time()
		await toad.get_tree().physics_frame
		elapsed += delta
		shot_clock += delta
		hop_clock += delta
		if shot_clock >= skills.retreat_shot_interval:
			shot_clock = 0.0
			toad.play_clip(&"Spit_Forward")
			toad.shoot_fan(skills.retreat_shot_count, skills.retreat_shot_spread, skills.retreat_shot_lead)
			toad.vfx.spit_forward()
		if hop_clock >= skills.retreat_hop_interval and toad.outer_platforms.size() > 1:
			hop_clock = 0.0
			await _leap_to_platform(_next_platform(), data)
	if not still_running(id):
		return
	toad.play_clip(&"Leap_Start")
	toad.vfx.begin_leap()
	await toad.leap_to(toad.home_point(), data.leap_height, data.leap_time)
	toad.play_clip(&"Leap_Land")
	toad.vfx.platform_land()
	ScreenShake.add_trauma(0.25)
	toad.dismiss_sentinels()
	finish(id)


## Rời state giữa chừng vì lý do nào (chết, bị chuyển state) thì nhện canh cũng rút, không để sót trên bệ
func exit() -> void:
	super()
	toad.dismiss_sentinels()


func _leap_to_platform(index: int, data: FireToadData) -> void:
	_platform_index = index
	toad.play_clip(&"Leap_Start")
	toad.vfx.begin_leap()
	await toad.leap_to(toad.outer_platforms[index].global_position, data.leap_height, data.leap_time)
	toad.play_clip(&"Leap_Land")
	toad.vfx.platform_land()


## Bệ khác bệ đang đứng
func _next_platform() -> int:
	var count := toad.outer_platforms.size()
	if count == 1:
		return 0
	var next := _rng.randi_range(0, count - 1)
	while next == _platform_index:
		next = _rng.randi_range(0, count - 1)
	return next
