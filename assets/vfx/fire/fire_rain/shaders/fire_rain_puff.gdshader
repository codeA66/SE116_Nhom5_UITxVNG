shader_type spatial;
// Cụm khói / quả cầu lửa tròn mép gợn (hạt CPUParticles3D): dùng cho khói đen cuộn lên và quả cầu lửa bùng khi
// cầu lửa chạm đất. Màu / độ mờ theo COLOR của color_ramp, nên một shader cho cả hai lớp (mỗi lớp material riêng).
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

// Lõi sáng hơn mép (quả cầu lửa) hay đều màu (khói)
uniform float core_boost = 0.0;
uniform float softness = 0.35;

varying float particle_seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	particle_seed = hash(vec2(float(INSTANCE_ID), 17.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	// Mép gợn như cụm khói: bán kính dao động theo góc
	float lobes = sin(angle * 3.0 + particle_seed * 6.28) * 0.57 + sin(angle * 5.0 - particle_seed * 4.0) * 0.43;
	float radius = 0.79 + 0.12 * lobes;
	float body = (1.0 - smoothstep(radius - softness, radius, r));
	float core = (1.0 - smoothstep(0.13, 0.60, r)) * core_boost;
	ALBEDO = COLOR.rgb * (1.0 + core);
	ALPHA = body * COLOR.a;
}
