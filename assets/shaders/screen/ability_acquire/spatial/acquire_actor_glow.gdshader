shader_type spatial;
// Lớp phủ (material_overlay) lên model cáo lúc hút năng lượng: viền sáng màu kỹ năng + ánh nhẹ toàn thân,
// cộng sáng lên màu gốc nên không đổi vật liệu của cáo. strength = 0 thì gần như không thấy.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(0.65, 0.88, 0.94, 1.0);
uniform float strength : hint_range(0.0, 4.0) = 0.0;
uniform float rim_power : hint_range(0.5, 8.0) = 2.2;
// Phần ánh phủ toàn thân so với viền
uniform float body_share : hint_range(0.0, 1.0) = 0.18;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = glow_color.rgb;
	ALPHA = clamp((rim + body_share) * strength, 0.0, 1.0);
}
