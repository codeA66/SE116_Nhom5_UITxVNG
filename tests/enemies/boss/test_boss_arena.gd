class_name TestBossArena
extends ZoneRoot
## Màn đấu trường kiểm tra Boss 1 với đầy đủ vũ khí và kỹ năng.

@export var grant_full_loadout: bool = true


func _ready() -> void:
	if grant_full_loadout:
		_grant_loadout()
	super._ready()


func _grant_loadout() -> void:
	# Cấp kỹ năng (Gió E để phản cầu lửa phá khiên, Lướt Space, Lửa Q)
	var dash := preload("res://abilities/dash/dash.tres") as AbilityData
	var wind := preload("res://abilities/wind_blast/wind_blast.tres") as AbilityData
	var fire := preload("res://abilities/flame_breath/flame_breath.tres") as AbilityData

	GameState.unlock_ability(dash)
	GameState.unlock_ability(wind)
	GameState.unlock_ability(fire)

	# Cấp vũ khí (Kiếm phím 1, Cung phím 2)
	var sword := preload("res://resources/combat/weapons/sword.tres") as WeaponData
	var bow := preload("res://resources/combat/weapons/bow.tres") as WeaponData

	GameState.add_weapon(sword)
	GameState.add_weapon(bow)
	GameState.select_weapon(WeaponData.Slot.SWORD)
