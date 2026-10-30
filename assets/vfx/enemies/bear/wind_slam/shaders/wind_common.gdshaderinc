uniform float age = -1.0;
uniform float warning_start = 0.04;
uniform float burst_time = 0.966667;
uniform float tail_duration = 2.2;
uniform vec4 wind_color : source_color = vec4(0.76, 0.87, 1.0, 1.0);
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1)), f.x), f.y);
}
float fbm(vec2 p) { return noise(p) * 0.57 + noise(p * 2.03 + 17.1) * 0.28 + noise(p * 4.11 + 3.7) * 0.15; }
float burst_envelope(float t) { return smoothstep(0.0, 0.09, t) * (1.0 - smoothstep(0.55, tail_duration, t)); }
