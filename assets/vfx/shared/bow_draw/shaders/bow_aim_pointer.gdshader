shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Mũi tên chỉ hướng dạng nét sáng (kiểu Death's Door): một vạch thân mảnh + đầu chữ V ở mép +Z (UV.y = 1),
// lõi sáng gần trắng và quầng mờ cùng màu bao quanh. Tính theo mét (pointer_size do code đặt) nên nét không
// bị kéo giãn khi đổi dài / rộng. Đang kéo: màu lạnh; đầy (ready = 1): màu ấm; hủy (cancel = 1): xám.
uniform vec4 draw_color : source_color = vec4(0.3, 0.68, 1.0, 1.0);
uniform vec4 ready_color : source_color = vec4(1.0, 0.66, 0.2, 1.0);
uniform vec4 cancel_color : source_color = vec4(0.4, 0.4, 0.42, 1.0);
uniform float ready : hint_range(0.0, 1.0) = 0.0;
uniform float cancel : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 2.0) = 1.0;
// Cỡ thật của mặt phẳng (m): x = bề ngang, y = chiều dài
uniform vec2 pointer_size = vec2(0.6, 1.1);
// Độ dày lõi nét, độ loang quầng, cỡ đầu chữ V (m)
uniform float core_width = 0.045;
uniform float glow_width = 0.09;
uniform float head_size = 0.24;

float segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * pointer_size.x, UV.y * pointer_size.y);
	vec2 tip = vec2(0.0, pointer_size.y - glow_width);
	float d = segment(p, vec2(0.0, glow_width), tip);
	d = min(d, segment(p, tip, tip + vec2(-head_size * 0.7, -head_size)));
	d = min(d, segment(p, tip, tip + vec2(head_size * 0.7, -head_size)));
	float core = 1.0 - smoothstep(core_width * 0.5, core_width, d);
	float glow = exp(-d / glow_width) * 0.55;
	// Đuôi nhạt dần để mũi tên như "mọc" ra từ tay
	float tail = smoothstep(0.0, pointer_size.y * 0.35, p.y);
	vec3 tint = mix(draw_color.rgb, ready_color.rgb, ready);
	vec3 color = mix(tint, mix(tint, vec3(1.0), 0.6), core);
	color = mix(color, cancel_color.rgb, cancel);
	ALBEDO = color;
	ALPHA = clamp(max(core, glow) * tail * opacity, 0.0, 1.0);
}
