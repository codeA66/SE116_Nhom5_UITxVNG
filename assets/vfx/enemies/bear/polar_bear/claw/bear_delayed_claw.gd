extends Node3D
signal finished
const TELEGRAPH = preload("res://assets/vfx/enemies/bear/polar_bear/claw/bear_telegraph.gdshader")
@export var telegraph_duration := 1.5
@export var screen_overlay: bool = false
@export var overlay_radius: float = 2.4
var age := -1.0
var manual_clock := false
var solo_layer := ""
var materials: Array[ShaderMaterial] = []
var overlay: ClawScreenOverlay
@onready var claw = $DarkClaw

func _ready() -> void:
	if screen_overlay:
		overlay = ClawScreenOverlay.new()
		overlay.world_radius = overlay_radius
		add_child(overlay)
	claw.manual_clock = true
	claw.set_process(false)
	claw.set_layer_enabled("Aura", false)
	for index in 2:
		var quad := MeshInstance3D.new()
		quad.mesh = QuadMesh.new()
		quad.mesh.size = Vector2.ONE * (3.65 if index == 0 else 4.4)
		quad.rotation.x = -PI * 0.5
		quad.position = Vector3(0.0, 0.04 + float(index) * 0.01, 0.0)
		var material := ShaderMaterial.new()
		material.shader = TELEGRAPH
		material.set_shader_parameter("soft_layer", index == 1)
		quad.material_override = material
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_node("Telegraph").add_child(quad)
		materials.append(material)
	set_color_variant(2)
	seek(-1.0)
	set_process(false)

func set_color_variant(index: int) -> void:
	var variant: Dictionary = claw.Style.COLOR_VARIANTS[index]
	claw.set_color_palette(variant.hue, variant.get("saturation", 1.0))
	var color: Color = claw.impact_light.light_color
	for material in materials: material.set_shader_parameter("tint", color)

func total_duration() -> float:
	return telegraph_duration + claw.style.duration * 0.885

func seek(seconds: float) -> void:
	age = seconds
	get_node("Telegraph").visible = age >= 0.0 and age < telegraph_duration + 0.10 and solo_layer in ["", "Telegraph"]
	for material in materials:
		material.set_shader_parameter("telegraph_age", age)
		material.set_shader_parameter("telegraph_duration", telegraph_duration)
	claw.visible = not screen_overlay and age >= telegraph_duration and age < total_duration() and solo_layer != "Telegraph"
	if overlay != null: overlay.seek(age - telegraph_duration if solo_layer != "Telegraph" else -1.0)
	claw.solo_layer = solo_layer if solo_layer != "Telegraph" else ""
	claw.seek(claw.style.duration * 0.115 + maxf(age - telegraph_duration, 0.0))

func play() -> void:
	seek(0.0)
	set_process(not manual_clock)

func _process(delta: float) -> void:
	seek(age + delta)
	if age >= total_duration():
		set_process(false)
		finished.emit()
