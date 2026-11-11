class_name SlimeMother
extends LavaSlime
## Slime Mẹ (mini-boss): to gấp mấy lần Slime Dung Nham, không tự nổ. Nảy đuổi (SlimeHop), vào tầm thì nhảy dậm
## (MotherSlam) tạo sóng chấn quanh chỗ đáp. Cứ brood_interval giây đẻ slime con (giữ tối đa max_children con),
## chết thì tách thành death_split_count con. Không khựng khi bị đánh / thổi (dữ liệu tắt stagger).
## Sóng chấn dùng lại ExplosionComponent của slime (mask chỉ player trong scene: không giết con mình).

signal brood_spawned(children: Array[Enemy])
signal slammed(center: Vector3, hit_count: int)

var mother_data: SlimeMotherData

var _brood_left: float = 0.0
var _children: Array[Enemy] = []


func _ready() -> void:
	super()
	mother_data = data as SlimeMotherData
	assert(mother_data != null, "%s: EnemyData phải là SlimeMotherData" % name)
	_brood_left = mother_data.brood_interval
	explosion.exploded.connect(func(center: Vector3, hits: int) -> void: slammed.emit(center, hits))


func _pre_state_update(delta: float) -> void:
	super(delta)
	if is_dead() or not has_target():
		return
	_brood_left -= delta
	if _brood_left <= 0.0:
		_brood_left += mother_data.brood_interval
		var room := mother_data.max_children - get_alive_children().size()
		spawn_children(mini(mother_data.brood_count, room))


## Không bị đánh bật (boss)
func resists_knockback() -> bool:
	return true


## Cú dậm chạm đất: sóng chấn quanh mình
func slam() -> void:
	explosion.explode(self)


## Mẹ không bao giờ tự nổ
func explode() -> void:
	pass


func get_alive_children() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for child in _children:
		if is_instance_valid(child) and not child.is_dead():
			alive.append(child)
	_children = alive
	return alive


## Đẻ count con quanh mẹ (cách đều theo vòng tròn), con nhận luôn mục tiêu của mẹ
func spawn_children(count: int) -> Array[Enemy]:
	var spawned: Array[Enemy] = []
	if count <= 0 or mother_data.child_scene == null:
		return spawned
	var parent := get_parent()
	var start_angle := randf() * TAU
	for i: int in range(count):
		var child := mother_data.child_scene.instantiate() as Enemy
		var angle := start_angle + TAU * float(i) / float(count)
		parent.add_child(child)
		child.global_position = global_position + Vector3(cos(angle), 0.0, sin(angle)) * mother_data.spawn_radius
		child.home_position = child.global_position
		if has_target():
			child.target = target
		_children.append(child)
		spawned.append(child)
	brood_spawned.emit(spawned)
	return spawned


func _on_died() -> void:
	# Gọi trễ: chết có thể xảy ra giữa callback va chạm, thêm node vào cây lúc đó không an toàn
	spawn_children.call_deferred(mother_data.death_split_count)
	super()
