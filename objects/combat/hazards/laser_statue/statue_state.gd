class_name StatueState
extends State
## Lớp cơ sở cho state của LaserStatue: lấy tượng từ owner một lần

var statue: LaserStatue


func _ready() -> void:
	statue = owner as LaserStatue
	assert(statue != null, "%s: StatueState phải nằm trong LaserStatue" % get_path())
