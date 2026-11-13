shader_type canvas_item;
// Ảnh cảnh game làm nền menu kiểu Hollow Knight: nhoè, nhuộm xanh đen, chỉ còn dáng cảnh mờ phía xa.
// Chỗ sáng (trời) thành ánh xanh nhạt, chỗ tối (tường cung điện) thành bóng đen.

uniform vec4 shadow_color : source_color = vec4(0.012, 0.018, 0.03, 1.0);
uniform vec4 glow_color : source_color = vec4(0.13, 0.19, 0.27, 1.0);
// Mức mipmap để nhoè (ảnh phải import có mipmap)
uniform float blur_lod : hint_range(0.0, 6.0) = 3.0;
uniform float low_cut : hint_range(0.0, 1.0) = 0.3;
uniform float high_cut : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec3 c = textureLod(TEXTURE, UV, blur_lod).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(shadow_color.rgb, glow_color.rgb, smoothstep(low_cut, high_cut, l));
	COLOR = vec4(col, COLOR.a);
}
