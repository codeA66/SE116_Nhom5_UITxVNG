// Lớp sáng của vệt chém (blend_add, HDR để glow toả ra): dải sáng xanh-trắng gió dày vừa ôm mép ngoài
// + vài "lưỡi gió" xanh nhỏ cong theo chiều quét bên trong thân đen. Mép sắc (fwidth), không blur.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://assets/shaders/combat/slash/slash_crescent.gdshaderinc"

uniform vec4 edge_color : source_color = vec4(0.45, 0.8, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.9, 0.98, 1.0, 1.0);
uniform float edge_intensity = 2.5;
uniform float core_intensity = 3.5;
// Bề dày dải sáng ngoài (theo UV.y) và phần lõi trắng của nó
uniform float band_width = 0.13;
uniform float core_width = 0.08;
// Lưỡi gió bên trong
uniform float blade_intensity = 1.8;
// Số lưỡi (0..5) và độ dài mỗi lưỡi theo chiều quét (tỉ lệ cung)
uniform float blade_count = 4.0;
uniform float blade_length = 0.28;
uniform float blade_width = 0.07;
uniform float blade_curve = 0.18;

void fragment() {
	float d_in;
	float d_out;
	float t;
	float s;
	crescent_shape(UV, d_in, d_out, t, s);
	float aa = max(fwidth(UV.y), 0.0005) * 1.5;
	float inside = smoothstep(0.0, aa, d_in) * smoothstep(0.0, aa, d_out) * step(0.0001, t);

	// Dải sáng ôm mép ngoài, bề dày co theo bề dày lưỡi để mũi nhọn không bị dày
	float band = band_width * clamp(t / thickness, 0.15, 1.0);
	float band_mask = 1.0 - smoothstep(band, band + aa, d_out);
	float core = 1.0 - smoothstep(core_width * 0.5, core_width, d_out);
	vec3 col = mix(edge_color.rgb * edge_intensity, core_color.rgb * core_intensity, core);
	float alpha = band_mask;

	// Lưỡi gió: mỗi lưỡi một vị trí ngang (c) và đoạn dọc cung riêng, trôi chậm theo chiều quét
	float c = d_in / max(t, 0.0001);
	float blades = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float on = step(fi + 0.5, blade_count);
		float start = slash_hash(vec2(fi, 3.0)) * (1.0 - blade_length);
		float x = (s - start) / blade_length;
		// lưỡi cong theo chiều quét: lệch ngang tăng dần về đuôi lưỡi
		float c_i = mix(0.25, 0.7, slash_hash(vec2(fi, 7.0))) - blade_curve * x * x;
		float w = blade_width * pow(clamp(x, 0.0, 1.0), 0.7) * pow(clamp(1.0 - x, 0.0, 1.0), 0.5) * 2.4;
		float dist = abs(c - c_i) - w;
		float in_range = step(0.0, x) * step(x, 1.0);
		float aa_b = max(fwidth(c), 0.001);
		blades = max(blades, (1.0 - smoothstep(-aa_b, aa_b, dist)) * in_range * on);
	}
	vec3 blade_col = edge_color.rgb * blade_intensity;
	col = mix(col, blade_col, blades * (1.0 - band_mask));
	alpha = max(alpha, blades);
	ALBEDO = col;
	ALPHA = clamp(alpha * inside, 0.0, 1.0);
}
