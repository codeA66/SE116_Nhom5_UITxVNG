class_name BananaItemEffects
extends RefCounted

static func particles(loop: bool) -> CPUParticles3D:
	var effect: CPUParticles3D = CPUParticles3D.new(); effect.amount = 14 if loop else 26; effect.lifetime = 0.6 if loop else 0.9
	effect.one_shot = not loop; effect.explosiveness = 0 if loop else 1; effect.local_coords = false
	effect.direction = Vector3.UP; effect.spread = 55; effect.gravity = Vector3.UP*0.3
	effect.initial_velocity_min = 0.3; effect.initial_velocity_max = 1.1; effect.scale_amount_min = 0.025; effect.scale_amount_max = 0.08
	var mesh: BoxMesh = BoxMesh.new(); mesh.size = Vector3(1,0.3,1); var mat: StandardMaterial3D = BananaItemModels.material(Color("62f89a"))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.emission_enabled = true; mat.emission = Color("25b950"); mesh.material = mat
	effect.mesh = mesh; effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; effect.emitting = false
	return effect

static func heal(player: Player) -> void:
	GardenCombatEffects.pulse(player.get_parent(),player.global_position+Vector3.UP*0.05,0.9,Color("6cff9d"))
	var effect: CPUParticles3D = particles(false); player.add_child(effect); effect.position.y = 0.4; effect.restart(); effect.emitting = true
	player.get_tree().create_timer(1.3,false).timeout.connect(effect.queue_free)
