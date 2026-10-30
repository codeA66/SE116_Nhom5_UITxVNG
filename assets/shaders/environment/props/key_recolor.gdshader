// Vật liệu cho chìa khoá dùng chung model: phần đỏ đổi sang màu khoá (tint), phát sáng nhẹ để chìa nổi trên sàn tối.
shader_type spatial;

#include "res://assets/shaders/environment/props/recolor.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.62, 0.32, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float lift : hint_range(0.5, 3.0) = 1.4;
uniform float glow : hint_range(0.0, 2.0) = 0.35;

void fragment() {
	vec3 col = recolor_red(COLOR.rgb, tint.rgb, strength, lift);
	ALBEDO = col;
	ROUGHNESS = 0.6;
	EMISSION = tint.rgb * glow;
}
