shader_type canvas_item;
// Nền màn Tab kiểu Death's Door: cảnh game phía sau làm mờ (mip của screen texture, cùng cách discovery_blur đã chạy trên
// Compatibility) rồi tối dần ra mép. Phủ kín (alpha 1) để mọi thứ phía dưới không lộ nét sắc.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 shade_color : source_color = vec4(0.03, 0.035, 0.05, 1.0);
// Mức mip đọc ảnh cảnh: càng lớn càng mờ
uniform float blur_lod : hint_range(0.0, 6.0) = 3.0;
// Độ tối toàn màn và độ tối thêm ở mép
uniform float base_dim : hint_range(0.0, 1.0) = 0.55;
uniform float edge_strength : hint_range(0.0, 1.0) = 0.7;
uniform float inner_radius : hint_range(0.0, 1.5) = 0.35;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.05;
// Giảm độ đậm màu cảnh phía sau để màu của đồ vật trên menu nổi hơn
uniform float desaturate : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec3 scene = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	float grey = dot(scene, vec3(0.299, 0.587, 0.114));
	scene = mix(scene, vec3(grey), desaturate);
	vec2 centered = (UV - 0.5) * vec2(1.6, 1.0);
	float edge = smoothstep(inner_radius, outer_radius, length(centered));
	float shade = clamp(base_dim + edge * edge_strength, 0.0, 1.0);
	COLOR = vec4(mix(scene, shade_color.rgb, shade), 1.0);
}
