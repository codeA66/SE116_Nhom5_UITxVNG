extends "res://tests/ui/hud/hud_preview.gd"
## USE CASE: máu/năng lượng/tiền/kỹ năng/prompt thật, cấu hình cực trị, dọn animation và giữ save.
## TEST CASE: damage/heal/max; spend/gain/insufficient; count-up; input/cooldown; focus/camera; 3s cleanup.
const Slot = preload("res://ui/hud/skills/slots/skill_slot.gd")
@export_group("Checks")
@export var capture_checks: bool = true
@export var cleanup_wait: float = 3.1
@export var epsilon: float = 0.01
@export var focus_only: bool = false
var _fails: int = 0
var _passes: int = 0
var _health_bar: HealthBar
var _energy_bar: EnergyBar
var _counter: CurrencyCounter
var _prompt: InteractionPrompt
var _vignette: HurtVignette
var _slot: Slot
var _activated: int = 0
var _interacted: int = 0
## Không gọi preview tự do: fixture tích hợp có trình tự rõ và tự kết thúc.
func _ready() -> void:
	_run.call_deferred()
## Mọi ca đi qua component/signal/input thật, không gọi _draw hoặc gán biến animation riêng.
func _run() -> void:
	configure_storage()
	await build_world(false)
	_health_bar = actor.get_node("HUD/GameHud/HealthPanel/HealthBar") as HealthBar
	_energy_bar = actor.get_node("HUD/EnergyBar") as EnergyBar
	_counter = actor.get_node("HUD/CurrencyCounter") as CurrencyCounter
	_prompt = actor.get_node("HUD/InteractionPrompt") as InteractionPrompt
	_vignette = actor.get_node("HUD/HurtVignette") as HurtVignette
	_slot = actor.get_node("HUD/GameHud/SkillCluster/SkillSlot") as Slot
	await wait_seconds(0.5)
	if focus_only:
		await _prompt_tests()
		print("HUD_RESULT passes=",_passes," fails=",_fails)
		await cleanup()
		get_tree().quit(1 if _fails else 0)
		return
	_check(actor.is_node_ready() and _health_bar.get_child_count()==actor.health.max_health,"Player và widget con khởi tạo đúng thứ tự")
	_check(not _energy_bar.is_processing() and not _counter.is_processing() and not _prompt.is_processing(),"HUD nghỉ không process liên tục")
	_check(_energy_bar.style.energy_label.is_empty() and _energy_bar.style.energy_pip_band<=0.0,"HUD mặc định chỉ hiện bình Linh lực")
	await _shot("hud_full")
	await _check_energy_pips(4,4)
	var floor_material: StandardMaterial3D = floor_visual.material_override as StandardMaterial3D
	var original_floor: Color = floor_material.albedo_color
	floor_material.albedo_color = Color("#b8b2a6")
	await wait_seconds(0.1)
	await _shot("hud_bright_floor")
	await _check_caption_contrast("sàn sáng")
	floor_material.albedo_color = Color("#152630")
	await wait_seconds(0.1)
	await _shot("hud_dark_floor")
	await _check_caption_contrast("sàn tối")
	floor_material.albedo_color = original_floor
	await _health_tests()
	await _energy_tests()
	await _currency_tests()
	await _skill_tests()
	await _prompt_tests()
	await _extreme_tests()
	await wait_seconds(cleanup_wait)
	_check(not _energy_bar.is_processing() and not _counter.is_processing() and not _prompt.is_processing(),"3s: bình/tiền/prompt hết xử lý")
	_check(_counter.is_showing() and not _prompt.visible,"3s: tiền vẫn hiện, prompt ẩn")
	_check(not _vignette.visible,"3s: viền đau không sót khi đã hồi máu")
	for child: Node in _health_bar.get_children(): _check(not child.is_processing(),"3s: đầu cáo hết vỡ/heal/pulse")
	for child: Node in actor.get_node("HUD/GameHud/SkillCluster").get_children():
		if child is Slot: _check(not child.is_processing(),"3s: slot hết cooldown/scale")
	await _shot("hud_after_three_seconds")
	print("HUD_RESULT passes=",_passes," fails=",_fails)
	await cleanup()
	get_tree().quit(1 if _fails else 0)
## Damage qua hurtbox xác minh viền đau lẫn hàng đầu cáo, không chỉ signal giả.
func _health_tests() -> void:
	var identities: PackedInt64Array = PackedInt64Array()
	for child: Node in _health_bar.get_children(): identities.append(child.get_instance_id())
	var hurtbox: HurtboxComponent = actor.get_node("HurtboxComponent") as HurtboxComponent
	var hit: DamageInfo = DamageInfo.new(1)
	hit.ignores_invincibility = true
	_check(hurtbox.receive_hit(hit),"hurtbox nhận đòn thật")
	await wait_seconds(0.06)
	_check(actor.health.current_health==4 and _vignette.visible,"damage trừ HP, hiện viền đau")
	await _shot("health_crack")
	await wait_seconds(0.6)
	_check(not bool(_health_bar.get_child(4).get(&"filled")),"đầu cáo thứ năm trở thành rỗng")
	for index: int in range(identities.size()): _check(_health_bar.get_child(index).get_instance_id()==identities[index],"damage tái dùng node đầu cáo")
	actor.health.heal_full()
	await _shot("health_heal")
	await wait_seconds(0.6)
	_check(bool(_health_bar.get_child(4).get(&"filled")) and not _vignette.visible,"heal lấp lại, viền đau tắt")
	actor.health.set_current_health(1)
	await wait_seconds(0.1)
	_check(_vignette.visible and _health_bar.get_child(0).is_processing(),"1 HP: tối viền và nhịp đầu cáo cuối")
	await wait_seconds(0.5)
	await _shot("health_one")
	await _check_bright_heads(1)
	await _check_tab_over_vignette()
	actor.health.set_current_health(2)
	await wait_seconds(0.6)
	await _shot("health_two")
	await _check_bright_heads(2)
	actor.health.heal_full()
	await wait_seconds(0.6)
	_check(not _vignette.visible,"hồi máu xóa cảnh báo nguy cấp")
	for maximum: int in [0,1,20]:
		actor.health.max_health = maximum
		actor.health.heal_full()
		await wait_seconds(0.1)
		_check(_health_bar.get_child_count()==maximum,"max HP %d dựng đúng số icon" % maximum)
		if maximum==20: await _shot("health_twenty")
	actor.health.max_health = 5
	actor.health.heal_full()
	await wait_seconds(0.6)
## Đếm đầu cáo sáng từ ảnh thật sau khi mảnh vỡ đã tan.
func _check_bright_heads(expected: int) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var bright: int = 0
	for node: Node in _health_bar.get_children():
		var head: Control = node as Control
		if sample_canvas(image,head,head.size*Vector2(0.5,0.40)).get_luminance() > 0.5:
			bright += 1
	_check(bright==expected,"ảnh thật: %d đầu cáo sáng, cần %d" % [bright,expected])
## Mẫu viền trang ở góc màn cho thấy menu nằm trên hiệu ứng khi 1 HP.
func _check_tab_over_vignette() -> void:
	var menu: InventoryMenu = actor.get_node(^"HUD/InventoryMenu") as InventoryMenu
	menu.open()
	await wait_seconds(0.45)
	_check(menu.visible and _vignette.visible and _vignette.get_index()<menu.get_index(),"Tab và lớp tối cùng mở, lớp tối nằm dưới")
	await _shot("tab_at_one")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var with_vignette: Image = get_viewport().get_texture().get_image()
		_vignette.hide()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var without_vignette: Image = get_viewport().get_texture().get_image()
		_vignette.show()
		var unaffected: bool = false
		var area: Rect2i = Rect2i(Vector2i(with_vignette.get_size()*0.018),Vector2i(with_vignette.get_size()*0.035))
		for y: int in range(area.position.y,area.end.y):
			for x: int in range(area.position.x,area.end.x):
				var pixel: Color = with_vignette.get_pixel(x,y)
				if pixel.get_luminance()>0.60 and pixel.is_equal_approx(without_vignette.get_pixel(x,y)):
					unaffected = true
		_check(unaffected,"ảnh thật: nét sáng menu Tab giữ nguyên khi lớp tối đang bật")
	menu.close()
	await wait_seconds(0.3)
## Đo nét sáng và viền tối trong đúng dải nhãn, cả trên nền sáng lẫn tối.
func _check_caption_contrast(floor_name: String) -> void:
	if DisplayServer.get_name()=="headless" or hud_style.energy_label.is_empty(): return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var outline_size: int = hud_style.text_outline_size
	hud_style.text_outline_size = 0
	_energy_bar.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var no_outline: Image = get_viewport().get_texture().get_image()
	hud_style.text_outline_size = outline_size
	_energy_bar.queue_redraw()
	var bottom: int = floori(_energy_bar.size.y-hud_style.energy_pip_band)
	var light_pixels: int = 0
	var ink_pixels: int = 0
	for y: int in range(bottom-hud_style.energy_font_size,bottom):
		for x: int in range(0,floori(_energy_bar.size.x)):
			var point: Vector2 = Vector2(x,y)
			var luminance: float = sample_canvas(image,_energy_bar,point).get_luminance()
			if luminance>0.76: light_pixels += 1
			# So cùng pixel khi tắt viền để không nhầm màu nền hoặc khử răng cưa.
			if sample_canvas(no_outline,_energy_bar,point).get_luminance()-luminance>0.025: ink_pixels += 1
	_check(light_pixels>10 and ink_pixels>10,"ảnh thật: nhãn LINH LỰC có nét sáng và viền trên "+floor_name)
## Max 0 không chia cho zero; max 1/10 và cảnh báo đều dùng API EnergyComponent.
func _energy_tests() -> void:
	actor.energy.data = actor.energy.data.duplicate(true) as EnergyData
	_check(actor.energy.spend(1),"tiêu năng lượng thành công")
	await wait_seconds(hud_style.energy_drop_time+0.1)
	_check(absf(_energy_bar.get_displayed_units()-float(actor.energy.current))<epsilon,"chất lỏng hội tụ sau spend")
	await _shot("energy_spent")
	await _check_energy_pips(4,3)
	actor.energy.gain_from_hit()
	await wait_seconds(0.55)
	_check(not _energy_bar.is_processing(),"nạp đầy xong hết ready pulse")
	actor.energy.set_current(2)
	var previous_fill: float = _energy_bar.get_fill_ratio()
	await wait_seconds(hud_style.energy_drop_time*0.5)
	_check(_energy_bar.get_fill_ratio()<previous_fill and _energy_bar.get_fill_ratio()>0.5,"mặt chất lỏng hạ dần, không nhảy thẳng")
	previous_fill = _energy_bar.get_fill_ratio()
	actor.energy.spend(1)
	_check(is_equal_approx(previous_fill,_energy_bar.get_fill_ratio()),"tiêu liên tiếp nối từ mức đang hiển thị")
	await wait_seconds(hud_style.energy_drop_time+0.1)
	_check(absf(_energy_bar.get_fill_ratio()-0.25)<epsilon,"tiêu liên tiếp hội tụ mức mới")
	actor.energy.set_current(2)
	await wait_seconds(hud_style.energy_full_time+0.1)
	await _shot("energy_half_continuous")
	await _check_energy_pips(4,2)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var surface: Control = _energy_bar.get_node("VesselSurface") as Control
		var lower: Color = sample_canvas(image,surface,surface.size*Vector2(0.5,0.70))
		var upper: Color = sample_canvas(image,surface,surface.size*Vector2(0.5,0.25))
		_check(lower.get_luminance()>upper.get_luminance()+0.2,"ảnh thật: phần dưới đầy, phần trên rỗng")
		var continuous: bool = true
		# Chân cáo che mép trái và đuôi che đáy, nên đo mực trong phần kính lộ ra.
		for horizontal: float in [0.35,0.45,0.55,0.65]:
			var pixel: Color = sample_canvas(image,surface,surface.size*Vector2(horizontal,0.64))
			continuous = continuous and pixel.get_luminance()>upper.get_luminance()+0.2
		_check(continuous,"ảnh thật: chất lỏng liền mạch, không có vạch chia")
	for maximum: int in [0,1,10,12,10000]:
		actor.energy.data.max_energy = maximum
		actor.energy.set_current(maximum)
		actor.energy.energy_changed.emit(actor.energy.current,actor.energy.get_max())
		await wait_seconds(0.6)
		_check(_energy_bar.get_displayed_max()==maximum,"sức chứa max %d" % maximum)
		_check(is_finite(_energy_bar.get_displayed_units()),"fill hữu hạn ở max %d" % maximum)
		if maximum==10: await _shot("energy_ten")
		if maximum>0 and maximum<=12:
			await _check_energy_pips(maximum,maximum)
	await _shot("energy_large")
	actor.energy.data.max_energy = 4
	actor.energy.set_current(0)
	await wait_seconds(0.4)
	await _shot("energy_empty")
	await _check_energy_pips(4,0)
	var rest: Vector2 = _energy_bar.position
	_check(not actor.energy.spend(1),"thiếu năng lượng trả false")
	await wait_seconds(0.08)
	await _shot("energy_insufficient")
	await wait_seconds(0.5)
	_check(_energy_bar.position.is_equal_approx(rest) and not _energy_bar.is_processing(),"cảnh báo trả vị trí và process")
	actor.energy.set_current(4)
	GameState.fuse(&"wind",WeaponData.Slot.SWORD)
	await wait_seconds(0.1)
	_check(_energy_bar.get_element_color()==hud_style.element_colors[&"wind"],"ghép gió đổi màu bình")
	await _shot("energy_wind")
	GameState.fuse(&"fire",WeaponData.Slot.SWORD)
	await wait_seconds(0.1)
	_check(_energy_bar.get_element_color()==hud_style.element_colors[&"fire"],"ghép lửa đổi màu bình")
	await _shot("energy_fire")
	GameState.unfuse(WeaponData.Slot.SWORD)
	_check(_energy_bar.get_element_color()==hud_style.energy_fallback,"tháo ghép về màu ngà")
## Hạt sáng đọc từ framebuffer để bắt trường hợp chỉ đổi số logic.
func _check_energy_pips(maximum: int,expected: int) -> void:
	if DisplayServer.get_name()=="headless" or hud_style.energy_pip_band<=0.0: return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var step: float = hud_style.energy_pip_diameter+hud_style.energy_pip_gap
	var first: Vector2 = Vector2((_energy_bar.size.x-step*(maximum-1))*0.5,_energy_bar.size.y-hud_style.energy_pip_band*0.5)
	var bright: int = 0
	for index: int in range(maximum):
		if sample_canvas(image,_energy_bar,first+Vector2.RIGHT*step*index).get_luminance()>0.4:
			bright += 1
	_check(bright==expected,"ảnh thật: %d/%d hạt sáng, cần %d" % [bright,maximum,expected])
## Khoản lớn không lặp một vòng cho từng đồng; tổng logic và chữ hoạt họa được kiểm tra riêng.
func _currency_tests() -> void:
	var skill_cluster: Control = actor.get_node("HUD/GameHud/SkillCluster") as Control
	var row_before: Rect2 = skill_cluster.get_global_rect()
	var label: Label = _counter.get_node(^"Count") as Label
	_check(_counter.is_showing() and label.text=="%s  0" % _counter.currency.display_name,"Soul Jade hiện 0 và lấy tên từ CurrencyData")
	await _shot("jade_zero_at_rest")
	GameState.add_currency(&"soul_jade",78)
	_check(_counter.is_showing() and _counter.get_shown_value()==78,"Soul Jade signal cập nhật tổng ngay")
	await wait_seconds(0.1)
	_check(_counter.get_displayed_value()<78,"số đang đếm thật, không nhảy thẳng đích")
	await _shot("currency_counting")
	await wait_seconds(0.55)
	_check(_counter.get_displayed_value()==78,"Soul Jade hội tụ 78")
	await _shot("jade_78")
	GameState.add_currency(&"soul_jade",1000137-78)
	await wait_seconds(0.6)
	_check(_counter.get_displayed_value()==GameState.get_currency(&"soul_jade"),"khoản lớn hội tụ chính xác")
	_check(label.text=="%s  1,000,137" % _counter.currency.display_name,"khoản lớn có phân nhóm hàng nghìn")
	await _shot("currency_large")
	_check_no_overlap("tiền lớn")
	_check(skill_cluster.get_global_rect().is_equal_approx(row_before),"Soul Jade đang hiện không dời hàng kỹ năng")
	await wait_seconds(cleanup_wait)
	_check(_counter.is_showing() and not _counter.is_processing(),"tiền tiếp tục hiện, dừng process")
	_check(skill_cluster.get_global_rect().is_equal_approx(row_before),"hết hiệu ứng tiền không dời hàng kỹ năng")
	GameState.add_currency(&"other_test",10)
	_check(not _counter.is_processing(),"loại tiền khác không kích hoạt Soul Jade")
## Cooldown qua signal Player, press qua Input.parse_input_event; không gọi play_press trực tiếp.
func _skill_tests() -> void:
	await _check_skill_bindings()
	_slot.activated.connect(_on_activated)
	var input: InputEventAction = InputEventAction.new()
	input.action = _slot.input_action
	input.pressed = true
	Input.parse_input_event(input)
	await get_tree().process_frame
	_check(_activated==1,"input action thật kích hoạt phản hồi ô")
	input.pressed = false
	Input.parse_input_event(input)
	var skill: SkillData = GameState.get_ability(&"wind_blast") as SkillData
	await wait_seconds(skill.get_lockout()+0.2)
	actor.wind_blast_cooldown_started.emit(0.5)
	await wait_seconds(0.12)
	_check(_slot.is_cooling_down(),"Player cooldown đi tới slot đúng id")
	await _shot("skill_cooldown")
	await wait_seconds(0.7)
	_check(not _slot.is_cooling_down(),"cooldown quét hết")
	var fire_slot: Slot = actor.get_node("HUD/GameHud/SkillCluster/FireSlot") as Slot
	actor.skill_cooldown_started.emit(&"flame_breath",0.3)
	_check(fire_slot.is_cooling_down() and not _slot.is_cooling_down(),"signal chung lọc đúng id, không làm ô gió hồi lại")
	await wait_seconds(0.5)
	_check(not fire_slot.is_cooling_down(),"ô lửa kết thúc cooldown từ signal chung")
	_slot.set_active(true)
	await wait_seconds(0.2)
	_check(_slot.selected and _slot.scale.x>1.0,"active tăng scale/viền")
	await _shot("skill_active")
	_slot.set_active(false)
	_check(_slot.is_in_group(&"ability_acquire_target"),"ô mới vẫn là target nhận kỹ năng")
	_slot.call(&"set_acquisition_pending",true)
	_check(not bool(_slot.call(&"is_available")),"pending nhận skill vẫn giấu icon mới")
	_slot.call(&"set_acquisition_pending",false)
	_check(bool(_slot.call(&"is_available")),"icon hiện khi đường bay tới HUD")
	await wait_seconds(0.2)
## Chuyển binding lúc chạy và xác nhận chính nửa nút chuột đổi sáng trên ảnh.
func _check_skill_bindings() -> void:
	if DisplayServer.get_name()=="headless": return
	var sword: Slot = actor.get_node(^"HUD/GameHud/SkillCluster/SwordSlot") as Slot
	var bow: Slot = actor.get_node(^"HUD/GameHud/SkillCluster/BowSlot") as Slot
	await _shot("skill_bindings")
	await RenderingServer.frame_post_draw
	var initial: Image = get_viewport().get_texture().get_image()
	_check(_mouse_pixel(initial,sword,false)>_mouse_pixel(initial,sword,true)+0.3,"ảnh thật: Kiếm ưu tiên chuột trái")
	_check(_mouse_pixel(initial,bow,true)>_mouse_pixel(initial,bow,false)+0.3,"ảnh thật: Cung hiện chuột phải")
	var bindings: Array[InputEvent] = InputMap.action_get_events(sword.input_action)
	var new_binding: InputEventMouseButton = InputEventMouseButton.new()
	new_binding.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_erase_events(sword.input_action)
	InputMap.action_add_event(sword.input_action,new_binding)
	await wait_seconds(0.4)
	await _shot("skill_rebound")
	await RenderingServer.frame_post_draw
	var rebound: Image = get_viewport().get_texture().get_image()
	_check(_mouse_pixel(rebound,sword,true)>_mouse_pixel(rebound,sword,false)+0.3,"ảnh thật: đổi Input Map cập nhật nút chuột")
	InputMap.action_erase_events(sword.input_action)
	for binding: InputEvent in bindings:
		InputMap.action_add_event(sword.input_action,binding)
	await wait_seconds(0.3)
## Lấy mẫu bên trong nửa trên của thân chuột.
func _mouse_pixel(image: Image,slot: Slot,right: bool) -> float:
	var center: Vector2 = slot.get_center()+hud_style.skill_badge_anchor*slot.radius
	var button: Vector2 = hud_style.skill_mouse_size*Vector2(0.22 if right else -0.22,-0.26)
	return sample_canvas(image,slot,center+button).get_luminance()
## Focus bằng Area3D thật và camera thật; sau khi vật bị gỡ, prompt phải tự hết.
func _prompt_tests() -> void:
	var target: InteractableComponent = InteractableComponent.new()
	target.prompt_text = "Nhặt kỹ năng"
	target.interacted.connect(_on_interacted)
	target.position = actor.global_position+Vector3(0,0.8,0.8)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.45
	collision.shape = shape
	target.collision_layer = actor.interactor.collision_mask
	target.add_child(collision)
	world.add_child(target)
	await wait_seconds(0.35)
	_check(actor.interactor.current==target and _prompt.visible,"interactor thật focus và hiện prompt")
	await _shot("interaction_prompt")
	var interact: InputEventKey = InputMap.action_get_events(&"interact")[0].duplicate() as InputEventKey
	interact.device = 0
	if interact.keycode==KEY_NONE: interact.keycode = interact.physical_keycode
	interact.pressed = true
	Input.parse_input_event(interact)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var released: InputEventKey = interact.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	Input.flush_buffered_events()
	print("HUD_INTERACT controls=",actor.controls_enabled," state=",actor.state_machine.current_state.name," pressed=",Input.is_action_pressed(&"interact")," floor=",actor.is_on_floor())
	_check(_interacted==1,"input phím thật đến vật đang focus (%d lần)" % _interacted)
	var initial: Vector2 = _prompt.position
	target.position.x += 0.35
	await wait_seconds(0.12)
	_check(_prompt.position.distance_to(initial)>epsilon,"prompt theo điểm 3D đang di chuyển")
	await _shot("interaction_follow")
	var camera: Camera3D = get_viewport().get_camera_3d()
	var previous_yaw: float = camera.rotation.y
	initial = _prompt.position
	camera.rotation.y += 0.04
	await wait_seconds(0.1)
	_check(_prompt.position.distance_to(initial)>epsilon,"camera đổi góc: prompt cập nhật điểm chiếu")
	camera.rotation.y = previous_yaw
	target.free()
	await wait_seconds(0.3)
	_check(not _prompt.visible and not _prompt.is_processing(),"mục tiêu gỡ: prompt hết và process off")
## Giá trị bằng không và rất lớn không làm UI vô hạn/tràn viewport; bản style gốc không bị đổi.
func _extreme_tests() -> void:
	var original: Style = hud_style
	var art_style: Style = original.duplicate(true) as Style
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = Gradient.new()
	texture.gradient.colors = PackedColorArray([Color.MAGENTA,Color.MAGENTA])
	art_style.health_full_texture = texture
	art_style.glyphs.erase(&"health")
	apply_style(art_style)
	await wait_seconds(0.1)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var head: Control = _health_bar.get_child(0) as Control
		var pixel: Color = sample_canvas(image,head,head.size*0.5)
		_check(pixel.r>0.9 and pixel.b>0.9 and pixel.g<0.1,"Texture2D override hiển thị thật dù không có glyph")
	apply_style(original)
	for large: bool in [false,true]:
		var extreme: Style = original.duplicate(true) as Style
		extreme.health_icon_size = Vector2.ONE*(10000.0 if large else 0.0)
		extreme.energy_size = Vector2.ONE*(10000.0 if large else 0.0)
		extreme.energy_shell_extent = 10000.0 if large else 0.0
		extreme.energy_inner_rim_opacity = 10000.0 if large else 0.0
		extreme.skill_radius = 10000.0 if large else 0.0
		extreme.skill_step = 10000.0 if large else 0.0
		extreme.line_width = 10000.0 if large else 0.0
		extreme.health_transition_time = 0.0
		extreme.energy_fill_time = 0.0
		extreme.currency_count_time = 0.0
		apply_style(extreme)
		actor.energy.set_current(0)
		actor.energy.notify_insufficient(1)
		actor.health.set_current_health(4)
		await wait_seconds(0.6)
		_check(is_finite(_energy_bar.get_displayed_units()),"cực trị fill hữu hạn")
		_check_no_overlap("style lớn" if large else "style zero")
		if not large: _check(not _slot.is_binding_visible(),"nhãn phím bị ẩn khi cỡ ô quá nhỏ")
		await _shot("extreme_large" if large else "extreme_zero")
		actor.health.heal_full()
	apply_style(original)
	actor.health.heal_full()
	actor.energy.set_current(4)
	await wait_seconds(0.6)
## Kiểm tra rect thật sau layout, không chỉ đọc tham số Resource.
func _check_no_overlap(label: String) -> void:
	var screen: Rect2 = Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
	var nodes: Array[Control] = [actor.get_node("HUD/GameHud/HealthPanel") as Control,_energy_bar,actor.get_node("HUD/GameHud/SkillCluster") as Control]
	for node: Control in nodes:
		_check(screen.encloses(node.get_global_rect()),label+": widget nằm trong viewport")
		if _counter.visible: _check(not _counter.get_global_rect().intersects(node.get_global_rect()),label+": Soul Jade không đè widget")
## Chụp chỉ khi render native; headless không được coi là đã duyệt hình ảnh.
func _shot(label: String) -> void:
	if capture_checks and DisplayServer.get_name()!="headless": await capture(label)
## Bắt tín hiệu activated để xác minh input đi đúng đường engine.
func _on_activated(_value: Slot) -> void:
	_activated += 1
## Đếm từ signal của mục tiêu, không xem việc bấm phím là đã tương tác thành công.
func _on_interacted(_actor: Node3D) -> void:
	_interacted += 1
## Đồng hồ test không dùng Tween ignore_time_scale bị lỗi trong project.
func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds,0.001)).timeout
## Tích lũy kết quả, vẫn chạy các ca sau khi một assertion thất bại.
func _check(condition: bool, label: String) -> void:
	if condition: _passes += 1
	else: _fails += 1
	print("PASS " if condition else "FAIL ",label)
