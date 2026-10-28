shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://assets/vfx/enemies/ice_spike/shaders/ice_common.gdshaderinc"
varying vec4 instance_data;
void vertex() {
	instance_data = INSTANCE_CUSTOM;
	float p = max(age - INSTANCE_CUSTOM.b * growth_time, 0.0);
	vec3 scale_value = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale_value.x, INV_VIEW_MATRIX[1] * scale_value.y, INV_VIEW_MATRIX[2] * scale_value.z, MODEL_MATRIX[3]);
	VERTEX.xy *= 0.45 + min(p, 1.8) * 0.7;
	VERTEX.y += p * 0.25;
	VERTEX.x += sin(INSTANCE_CUSTOM.g * 13.0 + p * 1.5) * p * 0.18;
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float p = max(age - instance_data.b * growth_time, 0.0);
	float n = fbm(q * 3.5 + instance_data.g * 71.0 + vec2(age * 0.5, -age * 0.3));
	float cloud = smoothstep(0.25, 0.7, n) * (1.0 - smoothstep(0.15, 1.0, length(q)));
	ALBEDO = mix(core_color.rgb * 0.35, edge_color.rgb, n);
	ALPHA = cloud * smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(shatter_time + 0.3, duration, age)) * 0.55;
}
