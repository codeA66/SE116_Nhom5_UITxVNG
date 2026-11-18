@tool
class_name SkillUpgradePickup
extends AbilityPickup
## Vật phẩm nâng cấp kỹ năng (Ấn Gió...): nhặt là kỹ năng tự lên cấp kế tiếp, kèm đúng màn giới thiệu như lúc học sách
## (dừng hình, tụ sáng, bảng giới thiệu). Bảng hiện dạng mới của kỹ năng ở cấp kế tiếp (Thổi Gió cấp 2 = Lốc xoáy).
## Chưa có kỹ năng gốc, đã tối đa cấp, hoặc vật phẩm chưa đủ cho cấp kế tiếp: chỉ nhận vật phẩm, không trình diễn.
## Thêm vật nâng cấp mới (Ấn Lửa...) = scene mới đổi ô Skill / Item, không sửa code.

## Kỹ năng gốc được nâng cấp (ví dụ abilities/wind_blast/wind_blast.tres)
@export var skill: AbilityData:
	set(value):
		skill = value
		update_configuration_warnings()
## Vật phẩm nhận được khi nhặt; dùng để trả giá nâng cấp (SkillUpgradeData.requirements)
@export var item: ItemData:
	set(value):
		item = value
		update_configuration_warnings()
@export var beam_color: Color = Color("a6e0ef")
## Cỡ biểu tượng vật phẩm lơ lửng (m)
@export var icon_size: float = 0.7


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
		# Không lên cấp được lúc này: nhận vật phẩm như đồ thường, để dành nâng sau trong Tab
		_interactable.enabled = false
		GameState.set_flag(persistent_id)
		GameState.add_item(item, 1)
		queue_free()
		return
	# Bảng giới thiệu của lớp cha đọc `ability`: cho nó hiện dạng mới của kỹ năng
	ability = next_form
	super._on_interacted(interactor)


## Gọi ở đỉnh màn trình diễn (AbilityPickup._commit_acquisition): nhận vật phẩm rồi trả giá nâng cấp ngay
func _give_to(_interactor: Node3D) -> void:
	GameState.add_item(item, 1)
	GameState.upgrade_ability(skill)


## Dạng kỹ năng ở cấp kế tiếp nếu nhặt vật phẩm này là đủ để nâng; null nếu không nâng được
func _next_form() -> AbilityData:
	var level := GameState.get_ability_level(skill)
	var step := skill.get_upgrade(level) if level > 0 else null
	if step == null:
		return null
	for cost: ItemCost in step.requirements:
		var have := GameState.get_item_count(cost.item) + (1 if cost.item == item else 0)
		if have < cost.count:
			return null
	return skill.resolve(level + 1)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if skill == null:
		warnings.append("Chưa gán Skill: kỹ năng gốc được nâng cấp (ví dụ wind_blast.tres).")
	if item == null:
		warnings.append("Chưa gán Item: vật phẩm nâng cấp (ví dụ wind_seal.tres).")
	return warnings


func _can_be_picked_by(interactor: Node3D) -> bool:
	return interactor is Player
