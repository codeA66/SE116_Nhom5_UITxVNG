shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Dải sáng nằm sâu trong khe nứt của tường giả: luôn le lói (gợi ý gió rò bên trong),
// crack_glow do SecretWall đẩy lên khi bị chém / thổi lúc chưa phá được rồi tắt dần.
uniform vec4 glow_color : source_color = vec4(0.25, 0.88, 0.82, 1.0);
uniform float idle_glow = 0.55;
uniform float crack_glow = 0.0;
uniform float pulse_speed = 1.6;

void fragment() {
	// Thở chậm để mắt bắt được khe nứt mà không chói
	float breathe = 0.85 + 0.15 * sin(TIME * pulse_speed);
	ALBEDO = glow_color.rgb * (idle_glow * breathe + crack_glow);
}
