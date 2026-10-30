// Vết máu loang trên sàn (PlaneMesh nằm ngang, sát đất): hình loang có thuỳ + vài giọt nhỏ quanh, mép sắc (fwidth).
// seed xoay / đổi hình ngẫu nhiên mỗi vết; progress 0..1: bung ra ease-out; fade 0..1: mờ dần cuối đời.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.4, 0.02, 0.04, 1.0);
uniform float seed = 0.0;
uniform float progress = 1.0;
uniform float fade = 0.0;
// Số giọt nhỏ vây quanh (0..3)
uniform float satellites = 3.0;

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float spin = hash(1.0) * 6.2831853;
	p = mat2(vec2(cos(spin), -sin(spin)), vec2(sin(spin), cos(spin))) * p;
	float grow = 1.0 - pow(1.0 - clamp(progress, 0.0, 1.0), 3.0);
	p = p / max(grow, 0.02);
	float ang = atan(p.y, p.x);
	float edge = 0.5 + 0.12 * sin(ang * 3.0 + hash(2.0) * 6.28) + 0.08 * sin(ang * 5.0 + hash(3.0) * 6.28) + 0.05 * sin(ang * 9.0 + hash(4.0) * 6.28);
	float d = edge - length(p);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float a = hash(10.0 + fi) * 6.2831853;
		float dist = 0.68 + 0.18 * hash(20.0 + fi);
		float rad = 0.05 + 0.06 * hash(30.0 + fi);
		float on = step(fi + 0.5, satellites);
		d = max(d, mix(-1.0, rad - length(p - vec2(cos(a), sin(a)) * dist), on));
	}
	float aa = max(fwidth(d), 0.002);
	float m = smoothstep(-aa, aa, d);
	ALBEDO = color.rgb * (0.85 + 0.15 * hash(40.0));
	ALPHA = m * (1.0 - smoothstep(0.0, 1.0, fade));
}
