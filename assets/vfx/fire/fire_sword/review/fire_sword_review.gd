extends "res://abilities/fusion/wind/vfx/slash/review/wind_vfx_review.gd"
## DONE: fixture chung kiểm tra instance FireSwordVfx có sẵn trong Player.
## NOT DONE: fixture không thay cho benchmark toàn map/export.
## NOTES: không sửa scene Player hoặc gameplay.
@export_group("Reference Capture")
@export var reference_direction: Vector3 = Vector3.FORWARD
@export var reference_target_position: Vector3 = Vector3(0.0, 0.0, -1.25)
@export var reference_spare_position: Vector3 = Vector3(2.7, 0.0, -1.6)
@export var reference_floor_color: Color = Color(0.35, 0.43, 0.56)
@export var reference_sample_fraction: float = 0.8
## Chọn family trước khi ready để giữ cùng trình tự so sánh.
func _init() -> void:
	element_id = &"fire"

## Ảnh thường giữ nguyên; ảnh đo riêng ẩn Model và giữ đồng hồ VFX để không đếm màu cáo vào diện tích lửa.
func _capture(label: String) -> void:
	await super._capture(label)
	if _headless or not label.begins_with("dark_fused_"): return
	var model: Node3D = player.get_node("Model") as Node3D
	var was_visible: bool = model.visible
	var was_processing: bool = vfx.is_processing()
	model.hide()
	vfx.set_process(false)
	await super._capture(label + "_isolated")
	model.visible = was_visible
	vfx.set_process(was_processing)

## Kiểm tra ngay ready và slot pool mới để không bỏ sót lượt đầu hay lượt tái dùng.
func _make_player(settings: Dictionary) -> void:
	await super._make_player(settings)
	var table: FusionTable = load("res://resources/combat/fusion/fusion_table.tres") as FusionTable
	var data: FusionData = table.get_fusion(WeaponData.Slot.SWORD, &"fire")
	for effect: FusionEffect in data.effects:
		if not effect is IgniteOnLastHitEffect: continue
		var ignite: IgniteOnLastHitEffect = effect as IgniteOnLastHitEffect
		var pool: ObjectPool = player.get_fusion_pool(ignite, ignite.touch_scene, ignite.pool_size)
		for slot: Node in pool.get_children():
			_check(not bool(slot.get_node("Vfx").get("visual_enabled")), "pool kiếm tắt visual cũ trước nhát đầu")

## Vùng đốt thật vẫn bật khi hình cũ tắt; cung phải giữ hình độc lập và dọn sạch.
func _test_hits() -> void:
	await super._test_hits()
	var table: FusionTable = load("res://resources/combat/fusion/fusion_table.tres") as FusionTable
	var data: FusionData = table.get_fusion(WeaponData.Slot.SWORD, &"fire")
	for effect: FusionEffect in data.effects:
		if not effect is IgniteOnLastHitEffect: continue
		var ignite: IgniteOnLastHitEffect = effect as IgniteOnLastHitEffect
		var pool: ObjectPool = player.get_fusion_pool(ignite, ignite.touch_scene, ignite.pool_size)
		for index: int in range(3):
			ignite.on_melee_active(player, _weapon.combo.back(), _weapon.combo.size() - 1, _weapon.combo.size(), direction, measure_active_time)
			_check(pool.get_active_count() > 0, "vùng đốt vẫn hoạt động khi bỏ visual cũ")
			for slot: Node in pool.get_children():
				var visual: Node = slot.get_node("Vfx")
				_check(not visual.is_processing() and not (visual.get_node("Burst") as Node3D).visible and not (visual.get_node("Ring") as Node3D).visible, "kiếm không ring, burst hay process cũ")
			await get_tree().create_timer(settle_time).timeout
		var slots: Array[Node] = []
		for index: int in range(pool.get_total_created() + 1): slots.append(pool.acquire())
		for slot: Node in slots:
			_check(not bool(slot.get_node("Vfx").get("visual_enabled")), "slot mới cũng tắt visual trước fired")
		pool.release_all()
	var bow: FusionData = table.get_fusion(WeaponData.Slot.BOW, &"fire")
	for effect: FusionEffect in bow.effects:
		if not effect is IgniteOnImpactEffect: continue
		var impact: IgniteOnImpactEffect = effect as IgniteOnImpactEffect
		impact.on_projectile_impact(player, direction, Vector3.UP)
		var busy: bool = false
		for visual: Node in player.find_children("*", "FireTouchVfx", true, false):
			busy = busy or (bool(visual.get("visual_enabled")) and visual.is_processing())
		_check(busy, "cung giữ VFX FireTouch riêng")
	await get_tree().create_timer(cleanup_time).timeout
	for visual: Node in player.find_children("*", "FireTouchVfx", true, false):
		_check(not visual.is_processing() and not (visual.get_node("Ring") as Node3D).visible, "FireTouch sạch sau ba giây")
	GameState.fuse(element_id, WeaponData.Slot.SWORD)
	for fraction: float in [0.25, 0.5, 0.85]:
		sample_fraction = fraction
		await _swing(_weapon.combo.size() - 1, "finisher_phase_%d" % roundi(fraction * 100.0))
	sample_fraction = 0.65
	await _reference_capture()

## Hai dummy thật, đánh đủ combo theo hướng ảnh mẫu; không tăng tầm hoặc làm giả số máu.
func _reference_capture() -> void:
	var dummy_scene: PackedScene = load("res://objects/combat/training_dummy/training_dummy.tscn") as PackedScene
	var target: TrainingDummy = dummy_scene.instantiate() as TrainingDummy
	var spare: TrainingDummy = dummy_scene.instantiate() as TrainingDummy
	target.position = reference_target_position
	spare.position = reference_spare_position
	add_child(target)
	add_child(spare)
	var spare_health: HealthComponent = spare.get_node("HealthComponent") as HealthComponent
	var initial_spare_health: int = spare_health.current_health
	var previous_direction: Vector3 = direction
	var previous_fraction: float = sample_fraction
	var floor_material: StandardMaterial3D = _floor.material_override as StandardMaterial3D
	var previous_color: Color = floor_material.albedo_color
	direction = reference_direction.normalized()
	sample_fraction = reference_sample_fraction
	floor_material.albedo_color = reference_floor_color
	await get_tree().physics_frame
	await get_tree().physics_frame
	for index: int in range(_weapon.combo.size()):
		await _swing(index, "reference_combo_%d" % (index + 1))
	_check(spare_health.current_health == initial_spare_health, "dummy ngoài tầm vẫn nguyên máu, VFX không thêm gameplay")
	await get_tree().create_timer(cleanup_time).timeout
	_check(_clean(), "cảnh mẫu trả hết pool sau ba giây")
	await _capture("reference_after_three")
	target.queue_free()
	spare.queue_free()
	direction = previous_direction
	sample_fraction = previous_fraction
	floor_material.albedo_color = previous_color

## Cực trị một/hai cung, độ phủ nhỏ/lớn và nhịp nhanh/chậm vẫn phải dọn sạch.
func _test_extremes() -> void:
	await super._test_extremes()
	var cases: Array[Dictionary] = [
		{"normal_streak_count": 1, "finisher_visual_scale": 0.2, "finisher_arc_degrees": 15.0, "finisher_streak_count": 1, "finisher_echo_delay": 0.0, "finisher_sweep_time": 0.001},
		{"normal_streak_count": 2, "finisher_visual_scale": 3.0, "finisher_arc_degrees": 250.0, "finisher_streak_count": 2, "finisher_echo_delay": 0.3, "finisher_sweep_time": 0.5}
	]
	for index: int in range(cases.size()):
		await _make_player(cases[index])
		GameState.fuse(element_id, WeaponData.Slot.SWORD)
		await _swing(0, "normal_count_%d" % index)
		await _swing(_weapon.combo.size() - 1, "finisher_extreme_%d" % index)
		await get_tree().create_timer(cleanup_time).timeout
		_check(_clean(), "nhát cuối cực trị sạch")
	await _make_player({})
