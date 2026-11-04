class_name GardenPlacedPeel
extends EnemyProjectile
@export var start_guide: GardenTotemGuide

func _ready() -> void:
	super(); place_peel(global_position)
	if start_guide != null and not start_guide.has_been_read:
		_peel_area.set_deferred("monitoring",false)
		set_physics_process(false)
		start_guide.read_completed.connect(_enable,CONNECT_ONE_SHOT)

func _enable() -> void:
	_peel_area.set_deferred("monitoring",true)
	set_physics_process(true)
