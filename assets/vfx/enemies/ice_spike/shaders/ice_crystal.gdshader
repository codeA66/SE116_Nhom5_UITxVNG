shader_type spatial;
render_mode cull_disabled;
#include "res://assets/vfx/enemies/ice_spike/shaders/ice_common.gdshaderinc"
varying vec3 bary;
varying float height_value;
varying vec4 instance_data;

void vertex() {
	instance_data = INSTANCE_CUSTOM;
	bary = COLOR.rgb;
	height_value = VERTEX.y;
	float grow = grow_at(INSTANCE_CUSTOM.b);
	VERTEX *= vec3(pow(max(grow, 0.001), 0.6), grow, pow(max(grow, 0.001), 0.6));
}
void fragment() {
	float birth = instance_data.b * growth_time;
	float broken = max(age - shatter_time - instance_data.b * 0.12, 0.0);
	float grain = hash21(floor(UV * vec2(9.0, 7.0)) + instance_data.g * 83.0);
	if (age < birth || broken > 0.16 || grain < broken / 0.16) { discard; }
	vec3 width = max(fwidth(bary), vec3(0.0001));
	vec3 inside = smoothstep(vec3(0.0), width * 0.45, bary);
	float edge = 1.0 - min(inside.x, min(inside.y, inside.z));
	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	float veins = pow(max(1.0 - abs(sin(UV.x * 23.0 + UV.y * 13.0 + instance_data.g * 8.0)) * 14.0, 0.0), 2.0) * 0.25;
	vec3 ice = mix(core_color.rgb * 0.36, core_color.rgb, clamp(height_value * 0.65 + 0.25, 0.0, 1.0));
	ALBEDO = mix(ice * 0.72, edge_color.rgb, clamp(edge * 0.65 + fresnel * 0.15, 0.0, 1.0));
	EMISSION = (ice * 0.08 + edge_color.rgb * (edge * 0.60 + veins * 0.30 + fresnel * 0.10)) * intensity;
	METALLIC = 0.18;
	ROUGHNESS = 0.18;
	SPECULAR = 0.8;
}
