shader_type spatial;
// Thân quái bóng tối (Sói Bóng Đêm): màu phẳng nhận sáng như StandardMaterial, cộng viền sáng xanh tím ở rìa
// (fresnel, đi vào EMISSION nên không phụ thuộc màu đèn trong cảnh: map lửa toàn đèn cam vẫn ra viền xanh tím).
// fade: tan vào bóng tối bằng đục lỗ theo ma trận Bayer 4x4 (discard), vật vẫn vẽ như vật đục:
// renderer Compatibility xử lý trộn alpha kém (vẽ lại mỗi đèn) nên không dùng trong suốt.
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(0.03, 0.03, 0.036, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform vec4 rim_color : source_color = vec4(0.45, 0.42, 1.0, 1.0);
// Độ hẹp của viền: lớn = viền mỏng sát mép
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 4.0) = 0.9;
// 0 = hiện đủ, 1 = biến mất hẳn
uniform float fade : hint_range(0.0, 1.0) = 0.0;

const float BAYER[16] = float[](
	0.0 / 16.0, 8.0 / 16.0, 2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0, 6.0 / 16.0,
	3.0 / 16.0, 11.0 / 16.0, 1.0 / 16.0, 9.0 / 16.0,
	15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0, 5.0 / 16.0);

void fragment() {
	if (fade > 0.0) {
		ivec2 cell = ivec2(mod(FRAGCOORD.xy, 4.0));
		if (fade > BAYER[cell.y * 4 + cell.x] + 0.03) {
			discard;
		}
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color.rgb * rim * rim_strength;
}
