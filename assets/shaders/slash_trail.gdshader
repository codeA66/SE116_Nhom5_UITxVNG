// Thân vệt chém lưỡi liềm ĐẶC ĐEN kiểu Death's Door: blend_mix, mép sắc (khử răng cưa bằng fwidth).
// Lòng cung tối dần vào trong tạo chiều sâu. Lớp sáng (viền ngoài + lưỡi gió) nằm ở slash_glow.gdshader.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://assets/shaders/slash_crescent.gdshaderinc"

// Màu thân sát mép ngoài và ở trong cùng (đen-xanh rất tối)
uniform vec4 body_color : source_color = vec4(0.015, 0.025, 0.05, 1.0);
uniform vec4 inner_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
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
	ALBEDO = mix(inner_color.rgb, body_color.rgb, smoothstep(0.0, 0.7, c));
	ALPHA = mask * layer_alpha;
}
