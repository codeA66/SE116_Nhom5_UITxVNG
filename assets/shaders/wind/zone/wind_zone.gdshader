// Dấu hiệu trên mặt đất của WindZone, cho người chơi biết phạm vi và hướng gió trước khi bước vào.
// Gió ngang: các vạch gió chạy sát đất theo hướng gió, phủ đúng diện tích vùng.

// Mesh là PlaneMesh cỡ 1 (đỉnh trong [-0.5, 0.5]); node được scale theo vùng.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://assets/shaders/wind/ambient/wind_flow.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.85, 0.94, 1.0, 1.0);
uniform float opacity = 0.35;
// Chiều dài vùng theo hướng gió (m), để vạch chạy đúng tốc độ
uniform float zone_length = 8.0;
uniform float dash_speed = 6.0;
uniform float row_count = 7.0;
uniform float dash_count = 3.0;
// Bề rộng vạch (m) và bề ngang vùng (m), để vạch luôn mảnh đúng kích thước thật
uniform float line_width = 0.05;
uniform float zone_width = 4.0;
uniform float fill_opacity = 0.18;
// Gió chặn người chơi: vạch thành mũi tên chữ V chỉ hướng gió, khoảng cách giữa các mũi tên (m)
uniform bool arrows = false;
uniform float arrow_spacing = 1.6;
uniform float arrow_slope = 0.9;
// 0..1: đang báo trước gió sắp bật (nhấp nháy ở mặt gió vào)
uniform float warning = 0.0;
uniform float warning_speed = 10.0;

varying vec2 v_local;

void vertex() {
	v_local = VERTEX.xz;
}

float crisp_band(float x, float half_width) {
	float aa = max(fwidth(x), 0.0001);
	return 1.0 - smoothstep(half_width - aa, half_width + aa, abs(x));
}

void fragment() {
	float alert = warning * (0.5 + 0.5 * sin(TIME * warning_speed));
	float alpha;
	float p = 0.5 - v_local.y;
	float lateral = (v_local.x + 0.5) * row_count;
	float row = floor(lateral);
	float in_row = fract(lateral) - 0.5;
	float seed = wind_hash(row + 1.0);
	// Vạch dài có đầu sáng, chạy theo hướng gió; mỗi hàng lệch pha để không đều như kẻ ô
	float travel = TIME * dash_speed / max(zone_length, 0.01);
	float f = fract((p - travel) * dash_count + seed * 3.0);
	float dash = smoothstep(0.0, 0.45, f) * (1.0 - smoothstep(0.55, 0.6, f));
	float line = crisp_band(in_row + (seed - 0.5) * 0.4, line_width * 0.5 * row_count / max(zone_width, 0.01));
	float mark = line * dash;
	if (arrows) {
		float row_width = zone_width / max(row_count, 1.0);
		float u = in_row * row_width;
		float along = (p - travel) * zone_length + seed * arrow_spacing;
		float v = mod(along, arrow_spacing) - arrow_spacing * 0.5;
		float chevron = crisp_band(v + abs(u) * arrow_slope, line_width);
		mark = chevron * step(abs(u), row_width * 0.35);
	}
	float edge_fade = smoothstep(0.0, 0.08, 0.5 - abs(v_local.x)) * smoothstep(0.0, 0.05, p) * smoothstep(0.0, 0.05, 1.0 - p);
	float live = wind_coverage(clamp(p, 0.0, 1.0));
	float inlet = (1.0 - smoothstep(0.0, 0.3, p)) * alert;
	alpha = (mark * (live + inlet) + fill_opacity * live) * edge_fade;
	ALBEDO = tint.rgb;
	ALPHA = clamp(alpha, 0.0, 1.0) * opacity * tint.a;
}
