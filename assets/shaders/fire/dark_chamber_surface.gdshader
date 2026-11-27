// Vật liệu cho phòng tối hoàn toàn: tắt fog môi trường (fog_disabled) để không bị sương đỏ nhuộm lộ đường,
// chỉ sáng lên khi có đèn cục bộ (lửa cầm tay, trụ đuốc) rọi vào.
shader_type spatial;
render_mode fog_disabled;

uniform vec4 albedo_color : source_color = vec4(0.05, 0.045, 0.045, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.95;
uniform float specular : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	ALBEDO = albedo_color.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
