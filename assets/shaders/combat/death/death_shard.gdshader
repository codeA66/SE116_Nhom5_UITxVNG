// Mảnh vỡ low-poly lúc quái chết: thân tối, viền fresnel phát sáng màu của quái. Có đèn nên có khối.
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec4 base_color : source_color = vec4(0.08, 0.07, 0.1, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float rim_strength = 2.5;
uniform float rim_power = 2.0;
// Phát sáng nhẹ cả mặt phẳng để mảnh vỡ không đen thui
uniform float base_glow = 0.25;

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.7;
	EMISSION = rim_color.rgb * (f * rim_strength + base_glow);
}
