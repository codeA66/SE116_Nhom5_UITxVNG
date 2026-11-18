shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

varying vec4 seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	seed = INSTANCE_CUSTOM;
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s.x,
		INV_VIEW_MATRIX[1] * s.y, INV_VIEW_MATRIX[2] * s.z, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float n = noise(p * 3.5 + seed.r * 43.0 + vec2(TIME * 0.45, -TIME * 0.8));
	float detail = noise(p * 8.0 + seed.b * 29.0);
	float edge = 1.0 - smoothstep(0.25, 1.0, length(p) + (n - 0.5) * 0.24);
	ALBEDO = COLOR.rgb * mix(vec3(0.72, 0.8, 0.83), vec3(1.0), n);
	ALPHA = COLOR.a * edge * mix(0.35, 0.85, n * 0.7 + detail * 0.3);
}
