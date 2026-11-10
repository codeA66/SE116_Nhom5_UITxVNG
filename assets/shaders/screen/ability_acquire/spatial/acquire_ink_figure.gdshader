shader_type spatial;
// Model cáo trên bảng nhận kỹ năng như nhân vật trên bảng Hollow Knight: khối trắng phát sáng,
// bóng nhẹ theo một hướng sáng cố định để vẫn đọc được tai, tay, đuôi; vành ngoài sáng nhất.
render_mode unshaded, cull_back;

// Màu phần khuất sáng và màu phần sáng nhất
uniform vec4 fill_color : source_color = vec4(0.5, 0.53, 0.58, 1.0);
uniform vec4 line_color : source_color = vec4(0.96, 0.98, 1.0, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.4;
uniform float rim_strength : hint_range(0.0, 4.0) = 0.6;
// Hướng sáng trong không gian nhìn (trên-trái-trước)
uniform vec3 light_dir = vec3(-0.35, 0.6, 0.72);

void fragment() {
	float light = clamp(dot(NORMAL, normalize(light_dir)), 0.0, 1.0);
	vec3 base = mix(fill_color.rgb, line_color.rgb, smoothstep(0.0, 0.85, light));
	float rim = clamp(pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power) * rim_strength, 0.0, 1.0);
	ALBEDO = mix(base, line_color.rgb, rim);
}
