extends EnemyHazard
## Vùng hút riêng rộng hơn vùng gây sát thương, theo dõi body bằng signal.
@export var pull_speed: float = 1.8
@export var pull_stop_radius: float = 0.55
var _bodies: Array[CharacterBody3D] = []
@onready var attraction: Area3D = $Attraction

func _ready() -> void:
	attraction.body_entered.connect(_on_body_entered)
	attraction.body_exited.connect(_on_body_exited)
	super()

func start(skill: EnemySkillData, at: Vector3, facing: Vector3) -> void:
	super(skill, at, facing)
	attraction.set_deferred(&"monitoring", true)

func pool_released() -> void:
	super()
	attraction.set_deferred(&"monitoring", false)
	_bodies.clear()

func _physics_process(delta: float) -> void:
	super(delta)
	if not running or not hitbox.is_active(): return
	for body: CharacterBody3D in _bodies:
		if not is_instance_valid(body): continue
		var toward: Vector3 = global_position - body.global_position
		toward.y = 0.0
		var distance: float = toward.length()
		if distance <= pull_stop_radius: continue
		# Dịch chuyển vật lý riêng nên input di chuyển không ghi đè lực hút.
		body.move_and_collide(toward / distance * minf(pull_speed * delta, distance - pull_stop_radius))

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body not in _bodies: _bodies.append(body as CharacterBody3D)

func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body)
