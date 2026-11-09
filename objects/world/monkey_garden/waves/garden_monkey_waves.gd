class_name GardenMonkeyWaves
extends Node3D
signal cleared
@export var reward: OfferingBanana
var completed: bool=false
var started: bool=false
var wave: int=0
var alive: int=0
var _player: Player
func is_cleared() -> bool: return completed
func begin(player: Player) -> void:
	if started: return
	started=true; _player=player; _spawn.call_deferred()
func _spawn() -> void:
	wave+=1
	var compositions: Array=[[4,0],[0,3],[3,2]]
	var composition: Array=compositions[wave-1]; alive=int(composition[0])+int(composition[1])
	for i: int in alive:
		var bomber: bool=i>=int(composition[0])
		var path: String="res://entities/enemies/wildlife/variants/banana_bomber/banana_bomber.tscn" if bomber else "res://entities/enemies/wildlife/monkey_grunt/monkey_grunt.tscn"
		var mob: WildEnemy=load(path).instantiate(); get_parent().add_child(mob)
		var angle: float=float(i)*TAU/alive
		mob.global_position=global_position+Vector3(cos(angle)*6,0.1,sin(angle)*6); mob.home_position=mob.global_position; mob.receive_rally(_player)
		mob.died.connect(_died)
func _died(_enemy: Enemy) -> void:
	alive-=1
	if alive>0: return
	if wave<3: get_tree().create_timer(1.3).timeout.connect(_spawn)
	else:
		completed=true; GardenRewards.offering(reward)
		get_tree().create_timer(2.2).timeout.connect(func() -> void: cleared.emit())
