shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Mũi tên chỉ hướng phát sáng nằm ngang tầm ngực (kiểu Death's Door): thân mảnh + đầu nhọn ở mép +Z (UV.y = 1).
// Đang kéo: màu lạnh; kéo đầy (ready = 1): đổi hẳn sang màu ấm và sáng hơn; hủy (cancel = 1): xám rồi tắt.
uniform vec4 draw_color : source_color = vec4(0.3, 0.68, 1.0, 1.0);
uniform vec4 ready_color : source_color = vec4(1.0, 0.66, 0.2, 1.0);
uniform vec4 cancel_color : source_color = vec4(0.4, 0.4, 0.42, 1.0);
uniform float ready : hint_range(0.0, 1.0) = 0.0;
uniform float cancel : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 2.0) = 1.0;
// Phần dài của đầu mũi tên (theo tỉ lệ chiều dài) và độ dày thân (theo tỉ lệ bề ngang)
uniform float head_length = 0.28;
uniform float shaft_width = 0.16;

void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float y = UV.y;
	float head_start = 1.0 - head_length;
	// Thân: dải mảnh, mờ dần về phía đuôi
	float shaft = (1.0 - smoothstep(shaft_width * 0.6, shaft_width, x)) * smoothstep(0.0, 0.35, y) * step(y, head_start + 0.02);
	// Đầu: tam giác nhọn
	float head_t = clamp((y - head_start) / head_length, 0.0, 1.0);
	float head_half = (1.0 - head_t) * 0.95;
	float head = (1.0 - smoothstep(head_half - 0.06, head_half, x)) * step(head_start, y) * step(y, 0.999);
	float shape = max(shaft, head);
	// Lõi sáng giữa thân và đầu
	float core = (1.0 - smoothstep(0.0, shaft_width * 0.45, x)) * smoothstep(0.2, 0.9, y);
	vec3 color = mix(draw_color.rgb, ready_color.rgb, ready);
	color = mix(color, vec3(1.0), core * 0.3);
	color = mix(color, cancel_color.rgb, cancel);
	ALBEDO = color;
	ALPHA = clamp(shape * opacity * mix(1.0, 1.35, ready), 0.0, 1.0);
}
