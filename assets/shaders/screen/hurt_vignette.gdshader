// Viền đỏ khi player bị đánh: tối dần ra mép, có gân nhiễu chuyển động. strength 0..1 do script tween.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.95, 0.05, 0.05, 1.0);
uniform float strength = 0.0;
// Bán kính (0..1.4) từ đó viền bắt đầu hiện
uniform float inner_radius = 0.55;
uniform float noise_scale = 5.0;
uniform float pulse_speed = 6.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p * vec2(1.0, 0.85));
	float n = vnoise(p * noise_scale + vec2(TIME * 0.7, -TIME * pulse_speed * 0.15));
	float edge = smoothstep(inner_radius + (n - 0.5) * 0.25, 1.35, d);
	float a = clamp(edge * (0.75 + 0.5 * n), 0.0, 1.0) * strength;
	COLOR = vec4(tint.rgb, a);
}
