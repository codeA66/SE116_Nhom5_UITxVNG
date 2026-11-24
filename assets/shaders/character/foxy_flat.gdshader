shader_type spatial;
render_mode unshaded, cull_back;
// Màu phẳng không nhận sáng (viền inverted hull, chấm sáng mắt của Foxy), tan biến cùng thân lúc chết
uniform vec4 color : source_color = vec4(1.0);

#include "res://assets/shaders/character/dissolve.gdshaderinc"

void vertex() {
	dissolve_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = color.rgb;
	ALBEDO += dissolve_edge_color.rgb * dissolve_apply() * dissolve_edge_glow;
}
