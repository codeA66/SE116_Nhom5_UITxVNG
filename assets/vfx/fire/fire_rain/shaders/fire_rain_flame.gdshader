shader_type spatial;
// Ngọn lửa bốc lên dọc dải cháy (hạt CPUParticles3D): hình giọt lửa thon nhọn phía trên, mép gợn theo noise,
// lõi sáng ở chân. Quad luôn quay về camera nhưng vẫn giữ cỡ hạt; màu / độ mờ theo COLOR của color_ramp.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.94, 0.67, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.62, 0.16, 1.0);
uniform vec4 outer_color : source_color = vec4(0.84, 0.16, 0.03, 1.0);

varying float particle_seed;

float hash(float n) {
	return fract(sin(n * 91.7) * 43758.5453);
}

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	particle_seed = hash(float(INSTANCE_ID) + MODEL_MATRIX[3].x * 3.1);
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	// Bề ngang giọt lửa: phình ở 25% chiều cao rồi nhọn dần lên đỉnh, mép gợn
	float profile = sin(clamp(p.y, 0.0, 1.0) * 3.14159 * 0.85 + 0.35) * (1.0 - p.y * 0.55);
	float wobble = 0.12 * sin(p.y * 10.0 - TIME * 14.0 + particle_seed * 20.0) * p.y;
	float d = abs(p.x - wobble) / max(profile, 0.001);
	float body = smoothstep(1.0, 0.55, d) * smoothstep(0.0, 0.08, p.y) * smoothstep(1.0, 0.75, p.y);
	float core = smoothstep(0.6, 0.0, d) * (1.0 - smoothstep(0.1, 0.55, p.y));
	vec3 color = mix(outer_color.rgb, hot_color.rgb, clamp(body * 1.3 - p.y * 0.4, 0.0, 1.0));
	color = mix(color, core_color.rgb, core);
	ALBEDO = color * COLOR.rgb;
	ALPHA = body * COLOR.a;
}
