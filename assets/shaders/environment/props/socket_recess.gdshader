// Lòng ổ đá trông như hốc lõm xuống sàn (sàn đặc, không đục được): đáy tối dần vào sát mép,
// vách trong một phía hứng sáng một phía chìm bóng, nhìn từ camera trên cao đọc ra là "cái hốc vừa viên đá".
shader_type spatial;
render_mode cull_back;

uniform vec4 floor_color : source_color = vec4(0.36, 0.38, 0.42, 1.0);
uniform vec4 deep_color : source_color = vec4(0.05, 0.06, 0.08, 1.0);
// Bán kính lòng ổ (m), khớp mesh
uniform float radius = 1.0;
// Bề rộng vành vách trong, tính theo phần của bán kính
uniform float wall_width : hint_range(0.05, 0.6) = 0.3;
// Hướng (mặt phẳng ngang) ánh nắng chiếu tới: vách phía đối diện hứng sáng
uniform vec2 light_dir = vec2(0.6, -0.8);
// Đáy sáng lên một chút ở tâm cho có khối, không thành lỗ đen phẳng
uniform float center_lift : hint_range(0.0, 2.0) = 0.8;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float r = clamp(length(local_pos.xz) / max(radius, 0.001), 0.0, 1.0);
	float wall = smoothstep(1.0 - wall_width, 1.0, r);
	vec2 dir = normalize(local_pos.xz + vec2(0.0001));
	float facing = dot(dir, -normalize(light_dir)) * 0.5 + 0.5;
	vec3 bottom = deep_color.rgb * (1.0 + center_lift * (1.0 - r));
	vec3 wall_col = mix(deep_color.rgb, floor_color.rgb, facing * 0.75);
	ALBEDO = mix(bottom, wall_col, wall);
	ROUGHNESS = 0.95;
}
