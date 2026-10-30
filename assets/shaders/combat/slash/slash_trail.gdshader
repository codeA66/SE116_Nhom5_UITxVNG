// Thân vệt chém lưỡi liềm SÁNG, vẽ đặc (blend_mix): trắng ngà ở mép ngoài, ngả vàng nhạt vào trong.
// Viền mực tối mảnh ôm cả hai mép để lưỡi tách khỏi mọi nền (sàn sáng, đèn, vùng gió xanh) mà không cần cộng sáng.
// Cùng shader làm bóng đổ trên sàn: đặt outline_width = 0, màu tối, layer_alpha thấp.
// Mép sắc khử răng cưa bằng fwidth. Hình học chung ở slash_crescent.gdshaderinc (khớp từng pixel với lớp sáng).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://assets/shaders/combat/slash/slash_crescent.gdshaderinc"

// Màu thân sát mép ngoài và ở trong cùng
uniform vec4 body_color : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform vec4 inner_color : source_color = vec4(0.95, 0.8, 0.5, 1.0);
// Viền mực: màu và bề dày (theo UV.y; 0 = tắt, dùng cho lớp bóng)
uniform vec4 outline_color : source_color = vec4(0.02, 0.025, 0.05, 1.0);
uniform float outline_width = 0.035;
// Đuôi lưỡi nhạt dần về màu trong khi teo, để mũi luôn sáng nhất
uniform float tail_fade = 0.35;
uniform float layer_alpha = 1.0;

void fragment() {
	float d_in;
	float d_out;
	float t;
	float s;
	crescent_shape(UV, d_in, d_out, t, s);
	float aa = max(fwidth(UV.y), 0.0005) * 1.5;
	float mask = smoothstep(0.0, aa, d_in) * smoothstep(0.0, aa, d_out) * step(0.0001, t);
	// c: 0 ở mép trong, 1 ở mép ngoài
	float c = clamp(d_in / max(t, 0.0001), 0.0, 1.0);
	vec3 col = mix(inner_color.rgb, body_color.rgb, smoothstep(0.0, 0.6, c));
	// Gần đuôi (xa mũi) thì ngả về màu trong
	float behind = clamp((head - s) / 0.8, 0.0, 1.0);
	col = mix(col, inner_color.rgb, behind * tail_fade);
	// Viền mực co theo bề dày lưỡi để mũi nhọn không thành cục đen
	float ow = outline_width * clamp(t / thickness, 0.3, 1.0);
	float edge = 1.0 - smoothstep(ow, ow + aa, min(d_in, d_out));
	col = mix(col, outline_color.rgb, edge * step(0.0001, outline_width));
	ALBEDO = col;
	ALPHA = mask * layer_alpha;
}
