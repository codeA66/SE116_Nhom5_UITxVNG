@tool
class_name SkillUpgradePickup
extends AbilityPickup
## Vật phẩm nâng cấp kỹ năng, nhặt là kỹ năng tự lên cấp kế tiếp, kèm đúng màn giới thiệu như lúc học sách
## (dừng hình, tụ sáng, bảng giới thiệu). Bảng hiện dạng mới của kỹ năng ở cấp kế tiếp (Thổi Gió cấp 2 = Lốc xoáy).
## Hai kiểu:
## - Có Item (Ấn Gió...): nhận vật phẩm rồi trả giá nâng cấp. Chưa có kỹ năng gốc, đã tối đa cấp, hoặc vật phẩm chưa
##   đủ cho cấp kế tiếp: chỉ nhận vật phẩm, không trình diễn.
## - Để trống Item (sách nâng cấp): nâng thẳng lên cấp kế tiếp, không tốn vật phẩm. Chưa có kỹ năng gốc thì sách
##   nằm yên, không nhặt được, gợi ý đổi thành locked_prompt; đã tối đa cấp thì cũng không nhặt được.
## Thêm vật nâng cấp mới (Ấn Lửa, sách...) = scene mới đổi ô Skill / Item, không sửa code.

## Kỹ năng gốc được nâng cấp (ví dụ abilities/wind_blast/wind_blast.tres)
@export var skill: AbilityData:
	set(value):
		skill = value
		update_configuration_warnings()
## Vật phẩm nhận được khi nhặt; dùng để trả giá nâng cấp (SkillUpgradeData.requirements). Trống = sách nâng cấp miễn phí
@export var item: ItemData
@export var beam_color: Color = Color("a6e0ef")
## Cỡ biểu tượng vật phẩm lơ lửng (m)
@export var icon_size: float = 0.7
## Sách nâng cấp: chữ gợi ý khi chưa có kỹ năng gốc (ví dụ "Cần Phun lửa"). Trống = giữ chữ gợi ý thường
@export var locked_prompt: String = ""

var _open_prompt: String = ""


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint() or is_queued_for_deletion():
		return
	_open_prompt = _interactable.prompt_text
	if item == null:
		# Học kỹ năng gốc ngay trong phòng thì sách đổi gợi ý theo, không cần vào lại
		GameState.ability_unlocked.connect(_on_ability_unlocked)
		_refresh_prompt()


func _build_visual(visual_root: Node3D) -> void:
	LootItemBeam.attach_to(visual_root.get_parent() as Node3D, beam_color).show()
	if item == null or item.icon == null:
		return
	var sprite := Sprite3D.new()
	sprite.texture = item.icon
	sprite.pixel_size = icon_size / maxf(float(item.icon.get_height()), 1.0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual_root.add_child(sprite)


func _on_interacted(interactor: Node3D) -> void:
	if not _can_be_picked_by(interactor):
		return
	var next_form := _next_form()
	if next_form == null:
		if item == null:
			# Sách: chưa học kỹ năng gốc / đã tối đa cấp thì sách nằm yên chờ
			_refresh_prompt()
			return
		# Không lên cấp được lúc này: nhận vật phẩm như đồ thường, để dành nâng sau trong Tab
		_interactable.enabled = false
		GameState.set_flag(persistent_id)
		GameState.add_item(item, 1)
		queue_free()
		return
	# Bảng giới thiệu của lớp cha đọc `ability`: cho nó hiện dạng mới của kỹ năng
	ability = next_form
	super._on_interacted(interactor)


## Gọi ở đỉnh màn trình diễn (AbilityPickup._commit_acquisition): nâng kỹ năng lên cấp kế tiếp
func _give_to(_interactor: Node3D) -> void:
	if item == null:
		GameState.grant_ability_level(skill, GameState.get_ability_level(skill) + 1)
		return
	GameState.add_item(item, 1)
	GameState.upgrade_ability(skill)


## Dạng kỹ năng ở cấp kế tiếp nếu nhặt vật này là nâng được; null nếu không nâng được
func _next_form() -> AbilityData:
	var level := GameState.get_ability_level(skill)
	var step := skill.get_upgrade(level) if level > 0 else null
	if step == null:
		return null
	if item != null:
		for cost: ItemCost in step.requirements:
			var have := GameState.get_item_count(cost.item) + (1 if cost.item == item else 0)
			if have < cost.count:
				return null
	return skill.resolve(level + 1)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if skill == null:
		warnings.append("Chưa gán Skill: kỹ năng gốc được nâng cấp (ví dụ wind_blast.tres).")
	return warnings


func _can_be_picked_by(interactor: Node3D) -> bool:
	return interactor is Player


## Sách: gợi ý báo cần kỹ năng gốc khi chưa học
func _refresh_prompt() -> void:
	var locked := not locked_prompt.is_empty() and not GameState.has_ability(skill.id)
	_interactable.prompt_text = locked_prompt if locked else _open_prompt


func _on_ability_unlocked(unlocked: AbilityData) -> void:
	if unlocked == skill:
		_refresh_prompt()
