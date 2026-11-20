shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform int kind = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
varying float flame_layer;

void vertex() {
	flame_layer = UV2.x;
	if (flame_layer > 0.5) {
		float height = kind == 2 ? 0.31 : 0.28;
		VERTEX.y *= height * mix(0.57, 1.0, progress);
		VERTEX.xz *= 1.0 + UV.y * 0.033 * sin(UV.x * 113.097 + TIME * 10.0);
	}
}

float spark_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 seed = fract(cell * vec2(0.3183, 0.3679));
	seed += dot(seed, seed.yx + 17.513);
	return fract(seed.x * seed.y);
}

void fragment() {
	vec3 blood = vec3(0.62, 0.012, 0.019);
	vec3 red = vec3(1.0, 0.048, 0.027);
	vec3 ember = vec3(1.0, 0.31, 0.078);
	float heat = smoothstep(0.28, 1.0, progress);
	if (flame_layer > 0.5) {
		float angle = UV.x * 6.283185;
		float tooth = sin(angle * 33.0 - TIME * 16.0 + 2.0 * sin(angle * 15.0 + TIME * 8.0));
		float gaps = sin(angle * 21.0 + TIME * 11.0) * 0.5 + 0.5;
		float height = (0.21 + 0.66 * pow(max(0.0, tooth), 1.6)) * (0.45 + 0.55 * gaps);
		float fray = sin(angle * 59.0 + UV.y * 13.0 - TIME * 20.0) * 0.08;
		float tongue = 1.0 - smoothstep(height - 0.045, height + 0.04, UV.y + fray * UV.y);
		float wrap = 1.0 - smoothstep(0.02, 0.18, UV.y);
		ALBEDO = mix(red, ember, wrap * (0.36 + 0.36 * gaps)) * (0.80 + 0.20 * gaps);
		ALPHA = tongue * (1.0 - UV.y * 0.84) * (0.44 + heat * 0.40);
	} else {
		vec2 point = (UV - 0.5) * 2.2;
		float radius = length(point);
		vec2 unit = point / max(radius, 0.01);
		float edge_chips = 0.005 * sin(dot(unit, vec2(106.0, 87.0)) - TIME * 4.0);
		float fringe = abs(radius - 0.986 + edge_chips);
		float aa = clamp(fwidth(radius) * 0.73, 0.003, 0.019);
		float core = 1.0 - smoothstep(0.012, 0.029 + aa, fringe);
		float ember_seam = 1.0 - smoothstep(0.004, 0.009 + aa, fringe);
		float halo = (1.0 - smoothstep(0.005, 0.13, fringe)) * (0.20 + 0.13 * heat);
		float stressed = 1.0 - smoothstep(0.009, 0.041, abs(radius - mix(0.31, 0.95, progress)));
		float grit = spark_noise(point * 73.0 + unit * sin(TIME * 6.0));
		float rents = pow(max(0.0, sin(dot(unit, vec2(44.0, 19.0)) + radius * 33.0)), 13.0);
		float strikes = rents * grit * smoothstep(0.68, 0.89, radius) * (1.0 - smoothstep(0.96, 1.02, radius));
		float ash = (1.0 - smoothstep(0.93, 0.99, radius)) * (0.075 + heat * 0.12) * (0.72 + grit * 0.28);
		ALBEDO = mix(blood, red, clamp(core * 0.86 + strikes * 0.4 + stressed * 0.33, 0.0, 1.0));
		ALBEDO = mix(ALBEDO, ember, ember_seam * (0.38 + grit * 0.48));
		ALPHA = max(max(core * (0.90 + 0.08 * heat), halo), max(ash, max(strikes * 0.4, stressed * (0.22 + heat * 0.18))));
	}
}
