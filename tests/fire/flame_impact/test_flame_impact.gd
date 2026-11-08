extends Node3D
## Hồi quy lỗi "FlameImpact.play: Trying to assign invalid previously freed instance":
## mục tiêu bị trúng lửa, một mesh con của nó bị giải phóng, rồi trúng lửa lần nữa.
## 1. Lần đầu: phủ màu lên đủ 2 mesh.
## 2. Giải phóng mesh thứ hai (giữ mesh đầu, đúng trường hợp cache cũ chỉ kiểm tra phần tử đầu) rồi trúng lần nữa:
##    không lỗi, chỉ phủ lên mesh còn sống; mesh mới thêm vào cũng được phủ.
## Chạy: godot --headless --path . res://tests/fire/flame_impact/test_flame_impact.tscn

const IMPACT: PackedScene = preload("res://assets/vfx/fire/flame_breath/impact/flame_impact.tscn")

var _failed: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var impact: FlameImpact = IMPACT.instantiate() as FlameImpact
	add_child(impact)
	var target: Node3D = Node3D.new()
	add_child(target)
	var hurtbox: HurtboxComponent = HurtboxComponent.new()
	target.add_child(hurtbox)
	var a: MeshInstance3D = _mesh(target, "A")
	var b: MeshInstance3D = _mesh(target, "B")
	await get_tree().process_frame
	impact.play(hurtbox)
	_check(a.material_overlay == impact.flash_material and b.material_overlay == impact.flash_material, "lần đầu: phủ màu lên 2 mesh")
	await get_tree().create_timer(impact.duration + 0.2).timeout
	b.free()
	var c: MeshInstance3D = _mesh(target, "C")
	impact.play(hurtbox)
	_check(a.material_overlay == impact.flash_material and c.material_overlay == impact.flash_material, "mesh con bị giải phóng giữa hai lần trúng: không lỗi, phủ mesh còn sống và mesh mới")
	print("FLAME IMPACT RESULT: %s" % ("OK" if _failed == 0 else "%d FAIL" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)


func _mesh(parent: Node3D, n: String) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.name = n
	m.mesh = BoxMesh.new()
	parent.add_child(m)
	return m


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("%s %s" % ["OK  " if ok else "FAIL", what])
