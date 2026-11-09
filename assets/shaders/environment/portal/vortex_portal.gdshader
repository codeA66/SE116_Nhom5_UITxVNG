shader_type spatial;
// Cổng xoáy năng lượng: đĩa tròn đứng, lõi xanh sáng xoáy ốc, viền khói xanh đậm tan dần ra ngoài.
// Không dùng texture: nhiễu fbm tính tại chỗ theo toạ độ cực đã xoắn. intensity 0 = cổng tắt (tối, mờ).
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 core_color : source_color = vec4(0.62, 0.93, 1.0, 1.0);
uniform vec4 mid_color : source_color = vec4(0.12, 0.5, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.02, 0.05, 0.2, 1.0);
// Độ xoắn: càng lớn vân càng cuộn vào tâm
uniform float swirl = 5.0;
uniform float speed = 0.7;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float ang = atan(c.y, c.x);
	float t = TIME * speed;
	float tw = ang + swirl * (1.0 - r) + t;
	vec2 p = vec2(cos(tw), sin(tw)) * (0.4 + r * 2.6);
	float n = fbm(p * 1.6 + vec2(t * 0.35, -t * 0.2));
	float wisps = fbm(p * 4.0 - vec2(t * 0.6, t * 0.4));
	float core = smoothstep(0.9, 0.05, r);
	vec3 col = mix(mid_color.rgb, core_color.rgb, clamp((n * 0.9 + wisps * 0.5) * core * 1.5, 0.0, 1.0));
	float edge = r + (n - 0.5) * 0.35;
	col = mix(rim_color.rgb, col, smoothstep(1.0, 0.6, edge));
	ALBEDO = col * mix(0.22, 1.5, intensity);
	ALPHA = smoothstep(1.0, 0.78, edge) * mix(0.6, 1.0, intensity);
}
