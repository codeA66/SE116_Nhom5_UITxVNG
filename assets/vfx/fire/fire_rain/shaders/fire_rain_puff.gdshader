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

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	particle_seed = hash(MODEL_MATRIX[3].xz * 3.7 + float(INSTANCE_ID));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	// Mép gợn như cụm khói: bán kính dao động theo góc
	float lobes = noise(vec2(angle * 2.2 + particle_seed * 30.0, particle_seed * 10.0 + TIME * 0.6));
	float radius = 0.72 + 0.22 * lobes;
	float body = smoothstep(radius, radius - softness, r);
	float core = smoothstep(0.55, 0.0, r) * core_boost;
	ALBEDO = COLOR.rgb * (1.0 + core);
	ALPHA = body * COLOR.a;
}
