uniform float age = 0.0;
uniform float duration = 1.25;
uniform float intensity = 1.0;
uniform float hue_shift = 0.0;
uniform float saturation_scale = 1.0;
uniform float shape_seed = 7.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.005, 0.025, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 4; i++) {
		value += noise21(p) * amplitude;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(17.1, 9.2);
		amplitude *= 0.47;
	}
	return value;
}

vec2 spin2(vec2 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float claw_time() { return clamp(age / max(duration, 0.01), 0.0, 1.0); }

// Hue variants keep saturation; Pearl removes saturation. HDR value and alpha stay intact.
vec3 palette_color(vec3 color) {
	if (abs(hue_shift) < 0.000001 && saturation_scale == 1.0) { return color; }
	float high = max(color.r, max(color.g, color.b));
	float low = min(color.r, min(color.g, color.b));
	float delta = high - low;
	if (delta < 0.000001) { return color; }
	float hue = 0.0;
	if (high == color.r) { hue = (color.g - color.b) / delta; }
	else if (high == color.g) { hue = (color.b - color.r) / delta + 2.0; }
	else { hue = (color.r - color.g) / delta + 4.0; }
	hue = fract(hue / 6.0 + hue_shift);
	vec3 rgb = clamp(abs(fract(vec3(hue) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return mix(vec3(1.0), rgb, delta / max(high, 0.000001) * saturation_scale) * high;
}
