shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://assets/vfx/enemies/wind_slam/shaders/wind_common.gdshaderinc"
varying vec4 instance_data;
void vertex() {
	instance_data = INSTANCE_CUSTOM;
	float t = max(age - burst_time, 0.0);
	vec3 size_value = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 at = MODEL_MATRIX[3].xyz;
	at.y += t * (0.5 + INSTANCE_CUSTOM.b * 1.4);
	at.x += sin(INSTANCE_CUSTOM.r * 25.0 + t * 2.0) * t * 0.6;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size_value.x, INV_VIEW_MATRIX[1] * size_value.y, INV_VIEW_MATRIX[2] * size_value.z, vec4(at, 1));
	VERTEX.xy *= 0.7 + t * 0.65;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float t = age - burst_time;
	float n = fbm(p * 3.3 + instance_data.r * 53.0 + vec2(age * 0.5, -age * 0.6));
	float cloud = smoothstep(0.27, 0.72, n) * (1.0 - smoothstep(0.15, 1.0, length(p)));
	ALBEDO = mix(wind_color.rgb * 0.48, vec3(0.96), n);
	ALPHA = cloud * burst_envelope(t) * 0.5;
}
