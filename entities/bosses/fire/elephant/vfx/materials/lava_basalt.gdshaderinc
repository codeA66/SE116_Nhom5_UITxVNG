vec2 basalt_hash(vec2 cell) {
	vec2 seed = fract(cell * vec2(0.1277, 0.1663));
	seed += dot(seed, seed.yx + 19.19);
	return fract(seed * vec2(seed.y, seed.x + seed.y));
}

float basalt_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 uv = fract(p);
	uv = uv * uv * (3.0 - 2.0 * uv);
	return mix(mix(basalt_hash(cell).x, basalt_hash(cell + vec2(1, 0)).x, uv.x),
		mix(basalt_hash(cell + vec2(0, 1)).x, basalt_hash(cell + 1.0).x, uv.x), uv.y);
}

// Khoảng cách tới mạch gãy giữa các mảng đá và độ sẫm của từng mảng.
vec2 basalt_fracture(vec2 p) {
	vec2 cell = floor(p);
	vec2 uv = fract(p);
	vec2 best = vec2(8.0);
	float tone = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 tile = vec2(float(x), float(y));
			vec2 seed = basalt_hash(cell + tile);
			vec2 delta = tile + 0.10 + 0.80 * seed - uv;
			float dist = dot(delta, delta);
			if (dist < best.x) {
				best = vec2(dist, best.x);
				tone = seed.x;
			} else {
				best.y = min(best.y, dist);
			}
		}
	}
	return vec2(sqrt(best.y) - sqrt(best.x), tone);
}

vec4 basalt_ground(vec2 p, float heat, float flash, float smoothing, float orange_shift) {
	float r = length(p);
	float angle = atan(p.y, p.x);
	float grain = basalt_noise(p * 67.0);
	float clay = basalt_noise(p * 23.0);
	vec2 warp = p + vec2(basalt_noise(p * 14.0), basalt_noise(p.yx * 13.0 + 28.0)) * 0.096;
	vec2 plate = basalt_fracture(warp * 7.4);
	float seam_width = mix(1.0, 0.77, orange_shift);
	float border = (0.010 + 0.006 * grain) * seam_width;
	float antialias = min(0.055, fwidth(plate.x) * smoothing);
	float cracks = 1.0 - smoothstep(border, border + 0.034 * seam_width + antialias, plate.x);
	float chips = (1.0 - smoothstep(0.018, 0.060, abs(sin(angle * 6.0 + sin(r * 27.0 + angle * 3.0) * 0.34))))
		* (0.32 + 0.68 * clay);
	float hot_channels = max(cracks, chips * mix(0.84, 0.30, orange_shift)) * (0.58 + 0.42 * grain);
	float light = min(1.0, hot_channels * heat + flash * 0.68);
	float bevel = smoothstep(0.026, 0.13, plate.x);
	vec3 basalt = mix(vec3(0.11, 0.071, 0.056), vec3(0.23, 0.17, 0.13), clamp(0.53 * plate.y + 0.32 * clay + grain * 0.22, 0.0, 1.0));
	basalt *= mix(0.44, 1.0, bevel);
	vec3 seam = mix(vec3(0.95, 0.065, 0.022), vec3(1.0, 0.27, 0.037), orange_shift);
	vec3 hot = mix(seam, vec3(1.0, 0.42, 0.09), light * light);
	return vec4(mix(basalt, hot, light), light);
}
