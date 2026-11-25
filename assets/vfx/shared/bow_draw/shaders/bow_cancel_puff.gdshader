shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Lớp 4 - khói xám tan ở đầu mũi tên khi thả sớm (hủy, không bắn): báo cho người chơi là phát này chưa bay.
// Hình khói tính bằng nhiễu; màu và độ mờ theo tuổi hạt (color_ramp của bộ hạt).
varying vec3 seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	seed = MODEL_MATRIX[3].xyz;
	vec3 scale_by = vec3(length(MODELVIEW_MATRIX[0].xyz), length(MODELVIEW_MATRIX[1].xyz), length(MODELVIEW_MATRIX[2].xyz));
	MODELVIEW_MATRIX[0] = vec4(scale_by.x, 0.0, 0.0, 0.0);
	MODELVIEW_MATRIX[1] = vec4(0.0, scale_by.y, 0.0, 0.0);
	MODELVIEW_MATRIX[2] = vec4(0.0, 0.0, scale_by.z, 0.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float n = noise(UV * 3.5 + seed.xz * 2.3);
	float puff = 1.0 - smoothstep(0.3, 1.0, length(p) + (n - 0.5) * 0.6);
	ALBEDO = COLOR.rgb * mix(0.8, 1.1, n);
	ALPHA = clamp(puff * COLOR.a, 0.0, 1.0);
}
