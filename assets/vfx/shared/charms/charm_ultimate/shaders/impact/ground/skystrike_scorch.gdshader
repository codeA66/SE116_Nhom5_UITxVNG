shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Hố xém dưới điểm nổ: tâm tối nhất, nhạt dần ra mép, mép lởm chởm theo nhiễu và nằm gọn trong bán kính
// (không lem ra ngoài vùng sát thương). Ảnh tro chỉ thêm vân bên trong.
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
// Bán kính phần tối đặc ở giữa và độ lởm chởm mép (theo tỉ lệ bán kính)
uniform float core_radius = 0.35;
uniform float edge_noise = 0.18;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float jag = noise(vec2(angle * 3.0, 1.7)) * 0.6 + noise(vec2(angle * 9.0, 4.2)) * 0.4;
	float edge = 0.92 - edge_noise + jag * edge_noise;
	float body = 1.0 - smoothstep(core_radius, edge, r);
	vec4 ash = texture(mask, UV);
	ALBEDO = tint.rgb * mix(0.55, 1.2, ash.r) * mix(0.7, 1.0, smoothstep(0.0, core_radius, r));
	ALPHA = clamp(body * mix(0.75, 1.0, ash.r), 0.0, 1.0) * opacity * (1.0 - step(1.0, r));
}
