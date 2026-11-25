shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Một nét mảnh (sợi gió tụ vào mũi tên / tia lửa bật ra lúc kéo đầy). Hạt xoay theo hướng bay (align_y) nên nét
// luôn nằm dọc đường bay; hai đầu nhọn, giữa sáng. Màu và độ mờ theo tuổi hạt (color_ramp của bộ hạt).
void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float y = UV.y;
	float taper = sin(y * PI);
	float line = 1.0 - smoothstep(0.15 * taper, 0.55 * taper + 0.001, x);
	ALBEDO = mix(COLOR.rgb, vec3(1.0), (1.0 - smoothstep(0.0, 0.2, x)) * 0.5);
	ALPHA = clamp(line * taper * COLOR.a, 0.0, 1.0);
}
