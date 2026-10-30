// Ngôi sao lóe 4 cánh (billboard, quad 1x1): hai cánh dài (trục x của quad) + hai cánh ngắn + chấm lõi tròn.
// Dùng cho mũi vệt chém và điểm trúng đòn. Mép sắc (khử răng cưa bằng fwidth), lõi HDR để glow ăn.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity = 2.5;
// 0..1 do script điều khiển: 1 = đang tắt
uniform float fade = 0.0;
// Độ dài cánh phụ so với cánh chính
uniform float short_arm = 0.4;
// Bán kính chấm lõi (0..1)
uniform float core_radius = 0.12;
// Xoay quanh trục nhìn (radian)
uniform float spin = 0.0;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float c = cos(spin);
	float sn = sin(spin);
	p = vec2(c * p.x - sn * p.y, sn * p.x + c * p.y);
	// Cánh: astroid kéo dài theo từng trục; trục y ngắn hơn
	vec2 q = vec2(abs(p.x), abs(p.y) / max(short_arm, 0.01));
	float a = pow(q.x, 0.38) + pow(q.y, 0.38);
	float aa = max(fwidth(a), 0.001);
	float arms = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, a);
	float core = 1.0 - smoothstep(core_radius - 0.02, core_radius, length(p));
	float m = max(arms, core) * (1.0 - fade);
	float edge_cut = 1.0 - smoothstep(0.9, 1.0, length(p));
	ALBEDO = tint.rgb * intensity;
	ALPHA = clamp(m * edge_cut, 0.0, 1.0);
}
