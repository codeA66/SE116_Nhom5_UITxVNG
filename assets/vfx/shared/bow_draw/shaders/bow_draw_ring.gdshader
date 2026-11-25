shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Lớp 1 - vòng tiến độ dưới chân khi kéo cung: rãnh mờ + cung sáng chạy theo chiều kim đồng hồ từ phía trên.
// Đầy (ready = 1) thì cả vòng đổi sang màu "sẵn sàng" và thở nhẹ; hủy (cancel = 1) thì xám và nhạt đi.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float ready : hint_range(0.0, 1.0) = 0.0;
uniform float cancel : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform vec4 track_color : source_color = vec4(0.1, 0.12, 0.14, 0.45);
uniform vec4 fill_color : source_color = vec4(0.72, 0.9, 1.0, 1.0);
uniform vec4 ready_color : source_color = vec4(1.0, 0.82, 0.42, 1.0);
uniform vec4 cancel_color : source_color = vec4(0.32, 0.26, 0.26, 1.0);
// Bán kính giữa và độ dày vòng (theo tỉ lệ nửa cạnh mesh)
uniform float radius = 0.82;
uniform float thickness = 0.12;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float band = 1.0 - smoothstep(thickness * 0.5 - 0.02, thickness * 0.5, abs(r - radius));
	// Góc 0 ở phía trên, tăng theo chiều kim đồng hồ khi nhìn từ trên xuống
	float angle = fract(atan(p.x, -p.y) / TAU + 1.0);
	float filled = step(angle, progress);
	float breathe = 0.85 + 0.15 * sin(TIME * 9.0);
	vec3 fill = mix(fill_color.rgb, ready_color.rgb * breathe, ready);
	vec3 color = mix(track_color.rgb, fill, filled);
	color = mix(color, cancel_color.rgb, cancel);
	float alpha = mix(track_color.a, 1.0, filled) * band;
	// Mép sáng ở đầu cung đang chạy để mắt bám theo
	float head = (1.0 - smoothstep(0.0, 0.03, abs(angle - progress))) * band * (1.0 - ready);
	color = mix(color, vec3(1.0), head * 0.8);
	ALBEDO = color;
	ALPHA = clamp(alpha + head, 0.0, 1.0) * opacity;
}
