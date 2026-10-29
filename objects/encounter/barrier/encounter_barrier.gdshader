// Ấn phong ấn chắn cửa (QuadMesh). Hai kiểu: vòng ấn đứng trong khung cửa, hoặc dải ấn nằm trên sàn ngưỡng cửa.
// draw 0..1 cho nét chạy quanh vòng / lan từ giữa ra (script tween lúc dựng); pulse chớp sáng lúc sập.
// Cộng sáng, không đọc màn hình (renderer Compatibility). Ký hiệu chỉ là gạch + chấm: ít nét, nhìn từ xa vẫn rõ.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.55, 0.82, 1.0, 1.0);
uniform float intensity = 1.4;
uniform float draw = 1.0;
// Vòng ký hiệu quay (vòng / giây), âm = ngược chiều
uniform float spin = 0.12;
uniform float glyphs = 12.0;
uniform bool strip = false;
// Dải: rộng / sâu, để gạch ký hiệu không bị kéo méo theo chiều rộng cửa
uniform float aspect = 1.0;
uniform float pulse = 0.0;

float band(float x, float c, float w) {
	return exp(-pow((x - c) / w, 2.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float val;
	if (strip) {
		float lines = band(p.y, 0.72, 0.09) + band(p.y, -0.72, 0.09);
		float cell = fract(p.x * aspect * 0.5 + TIME * spin);
		float dash = step(0.3, cell) * step(cell, 0.62) * band(p.y, 0.0, 0.16);
		float dots = band(cell, 0.8, 0.05) * band(p.y, 0.0, 0.1);
		float reach = step(abs(p.x), draw);
		float ends = 1.0 - smoothstep(0.92, 1.0, abs(p.x));
		val = (lines * 0.8 + dash * 0.7 + dots * 0.7) * reach * ends;
	} else {
		float r = length(p);
		float ang = atan(p.y, p.x) / 6.2832 + 0.5;
		float seg = fract(fract(ang + TIME * spin) * glyphs);
		float outer = band(r, 0.88, 0.035);
		float inner = band(r, 0.6, 0.025);
		float glyph = step(0.18, seg) * step(seg, 0.52) * band(r, 0.74, 0.05);
		float dots = band(seg, 0.76, 0.045) * band(r, 0.74, 0.035);
		float reach = step(ang, draw);
		val = (outer + inner * 0.6 + glyph * 0.8 + dots * 0.8) * reach;
	}
	ALBEDO = tint.rgb * intensity * (1.0 + pulse * 2.0);
	ALPHA = clamp(val, 0.0, 1.0);
}
