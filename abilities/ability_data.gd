class_name AbilityData
extends Resource
## Dữ liệu một kỹ năng mở khóa được (dash, double jump, skill...).
## Kỹ năng cụ thể kế thừa lớp này và thêm thông số riêng.

## Số La Mã cho tên cấp mặc định (cấp 1 không ghi số)
const LEVEL_NUMERALS: PackedStringArray = ["", "", "II", "III", "IV", "V"]

## Định danh duy nhất, nhân vật dùng để kiểm tra đã mở khóa chưa
@export var id: StringName
@export var display_name: String = ""
@export_group("Acquisition presentation")
@export var icon: Texture2D
@export var accent_color: Color = Color("#a6e0ef")
@export_multiline var description: String = ""
## Ảnh minh họa vẽ sẵn; chỉ dùng khi illustration_animation để trống
@export var illustration: Texture2D
@export var particle_texture: Texture2D
## Dòng nhỏ phía trên tên trên bảng nhận kỹ năng (ví dụ "Đã lĩnh hội")
@export var acquire_verb: String = ""
## Câu hướng dẫn trên bảng nhận kỹ năng; {key} được thay bằng hình phím thật. Trống = câu mặc định của bảng
@export var acquire_prompt: String = ""
## Hình minh họa dựng từ chính model cáo: animation trong foxy.glb và giây tạo dáng. Trống = dùng ảnh illustration
@export var illustration_animation: StringName
@export_range(0.0, 10.0, 0.01) var illustration_time: float = 0.0
## Hiệu ứng chiêu vẽ bên cạnh hình cáo (vật liệu shader canvas, mỗi kỹ năng một file). Trống = chỉ có hình cáo
@export var illustration_effect: Material
@export_group("Upgrades")
## Các bậc nâng cấp theo thứ tự (phần tử 0 = cấp 1 -> 2). NPC nâng cấp khi đủ vật phẩm; trống = không nâng cấp được
@export var upgrades: Array[SkillUpgradeData] = []
@export_group("Gameplay")
## Số ô năng lượng mỗi lần dùng (0 = miễn phí, ví dụ Dash)
@export_range(0, 20) var energy_cost: int = 0

## Dạng của kỹ năng theo cấp, dựng một lần rồi dùng lại (dữ liệu cố định nên không cần làm mới)
var _forms: Dictionary[int, AbilityData] = {}


func get_max_level() -> int:
	return 1 + upgrades.size()


## Bậc nâng cấp từ cấp level lên level+1; null nếu đã tối đa
func get_upgrade(level: int) -> SkillUpgradeData:
	var index := level - 1
	return upgrades[index] if index >= 0 and index < upgrades.size() else null


## Dạng kỹ năng dùng ở một cấp: đi qua từng bậc, bậc có evolves_into thì đổi sang kỹ năng đó,
## overrides của các bậc sau lần đổi gần nhất được áp lên một bản sao. Cấp 1 trả về chính nó
func resolve(level: int) -> AbilityData:
	level = clampi(level, 1, get_max_level())
	if _forms.has(level):
		return _forms[level]
	var form: AbilityData = self
	var changes: Dictionary[StringName, Variant] = {}
	for index in level - 1:
		var step := upgrades[index]
		if step == null:
			continue
		if step.evolves_into:
			form = step.evolves_into
			changes.clear()
		changes.merge(step.overrides, true)
	if not changes.is_empty():
		form = form.duplicate()
		for property: StringName in changes:
			form.set(property, changes[property])
	_forms[level] = form
	return form


## Tên hiển thị ở một cấp: lấy tên đặt riêng của bậc, không có thì tên gốc + số La Mã
func get_level_name(level: int) -> String:
	if level <= 1:
		return display_name
	var step := get_upgrade(level - 1)
	if step and not step.display_name.is_empty():
		return step.display_name
	var numeral := LEVEL_NUMERALS[level] if level < LEVEL_NUMERALS.size() else str(level)
	return "%s %s" % [display_name, numeral]
