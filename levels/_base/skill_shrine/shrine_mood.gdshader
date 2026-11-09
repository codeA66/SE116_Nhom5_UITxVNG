shader_type canvas_item;
// Không khí phòng học kỹ năng, phủ toàn màn hình: tối dần ra ngoài quanh chỗ sách (đi vào phòng), và rút màu +
// phủ sương nhạt (học xong, nơi này cạn sức mạnh: tham khảo căn phòng hoá trắng đen sau khi nhận phép ở Hollow Knight).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float dim = 0.0;
uniform float desaturate = 0.0;
uniform float fog = 0.0;
uniform vec2 focus = vec2(0.5, 0.5);
uniform float aspect = 1.7778;
uniform float clear_radius = 0.22;
uniform float falloff = 0.55;
uniform vec4 shade_color : source_color = vec4(0.02, 0.03, 0.06, 1.0);
uniform vec4 fog_color : source_color = vec4(0.82, 0.86, 0.9, 1.0);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), desaturate);
	vec2 off = (SCREEN_UV - focus) * vec2(aspect, 1.0);
	float edge = smoothstep(clear_radius, clear_radius + falloff, length(off));
	c = mix(c, shade_color.rgb, dim * edge);
	c = mix(c, fog_color.rgb, fog * (0.35 + 0.65 * edge));
	COLOR = vec4(c, 1.0);
}
