class_name CrumblingFloor
extends StaticBody3D
## Ô sàn sụp: có người (player/quái) bước lên thì rung rồi rơi sau crack_time giây, một lúc sau hiện lại.
## Mỗi ô độc lập: nhiều ô ghép thành cầu sụp, ô nào bị dẫm ô đó mới rơi.
## Hành vi theo FSM dạng node (objects/crumbling_floor/states/).

signal crumbled
signal restored

@export var data: CrumblingFloorData
## Kích thước mặt ô (m). Va chạm, vùng dò và hình đều dựng theo ô này
@export var size: Vector3 = Vector3(2.0, 0.4, 2.0)
## Hình ô nhỏ hơn va chạm bấy nhiêu mét: lộ khe giữa các ô để người chơi nhận ra đây là sàn sắp sụp
@export_range(0.0, 0.5, 0.01) var visual_gap: float = 0.14

## Độ lệch hình so với vị trí gốc, state ghi (rung, rơi)
var visual_offset: Vector3 = Vector3.ZERO

@onready var state_machine: StateMachine = $StateMachine
@onready var visual: Node3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _detector: Area3D = $Detector


func _ready() -> void:
	if data == null:
		push_error("%s thiếu CrumblingFloorData, ô sàn đứng yên" % get_path())
		set_physics_process(false)
		return
	_apply_size()
	_detector.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)


func set_solid(solid: bool) -> void:
	_collision.set_deferred(&"disabled", not solid)
	_detector.set_deferred(&"monitoring", solid)
	visual.visible = true


func set_visual_offset(offset: Vector3) -> void:
	visual_offset = offset
	visual.position = offset


func hide_visual() -> void:
	visual.visible = false


## Mỗi ô có shape riêng (tạo một lần) để chỉnh size từng ô không ảnh hưởng ô khác
func _apply_size() -> void:
	var box := BoxShape3D.new()
	box.size = size
	_collision.shape = box
	_collision.position.y = -size.y * 0.5
	var area_box := BoxShape3D.new()
	# Vùng dò mỏng nằm ngay trên mặt ô, hơi thu vào để đứng mép ô bên cạnh không kích ô này
	area_box.size = Vector3(maxf(size.x - 0.1, 0.1), 0.4, maxf(size.z - 0.1, 0.1))
	var area_shape := _detector.get_node("CollisionShape3D") as CollisionShape3D
	area_shape.shape = area_box
	area_shape.position.y = 0.2
	var mesh := visual.get_node_or_null("Mesh") as MeshInstance3D
	if mesh and mesh.mesh is BoxMesh:
		var m := (mesh.mesh as BoxMesh).duplicate() as BoxMesh
		m.size = Vector3(maxf(size.x - visual_gap, 0.05), size.y, maxf(size.z - visual_gap, 0.05))
		mesh.mesh = m
		mesh.position.y = -size.y * 0.5


func _on_body_entered(_body: Node3D) -> void:
	(state_machine.current_state as CrumblingFloorState).on_stepped()


## State gọi khi ô rơi / hiện lại: signal phát từ chính class khai báo nó
func notify_crumbled() -> void:
	crumbled.emit()


func notify_restored() -> void:
	restored.emit()
