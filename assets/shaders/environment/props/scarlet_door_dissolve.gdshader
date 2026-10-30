shader_type spatial;
render_mode cull_disabled;

uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.14, 0.08, 1.0);
uniform float edge_width : hint_range(0.01, 0.15) = 0.055;
uniform float edge_energy : hint_range(0.0, 4.0) = 1.8;
// Cửa màu khác dùng chung model đỏ: đổi phần đỏ sang recolor_tint (0 = giữ đỏ)
uniform vec4 recolor_tint : source_color = vec4(1.0, 0.14, 0.08, 1.0);
uniform float recolor_strength : hint_range(0.0, 1.0) = 0.0;
uniform float recolor_lift : hint_range(0.5, 3.0) = 1.3;
// Phủ màu recolor_tint lên cả cánh cửa (không chỉ phần đỏ), giữ độ sáng tối để còn thấy chi tiết. 0 = không phủ
uniform float panel_tint_strength : hint_range(0.0, 1.0) = 0.0;
varying vec3 object_position;

#include "res://assets/shaders/environment/props/recolor.gdshaderinc"

float cell_noise(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	object_position = VERTEX;
}

void fragment() {
	float radial = distance(object_position.xy, vec2(0.0, 1.58)) / 3.2;
	float pattern = radial * 0.72 + cell_noise(floor(object_position * 7.0)) * 0.28;
	float threshold = dissolve * 1.4 - 0.2;
	if (pattern < threshold) {
		discard;
	}
	float edge = (1.0 - smoothstep(threshold, threshold + edge_width, pattern)) * step(0.01, dissolve);
	vec3 base = recolor_red(COLOR.rgb, recolor_tint.rgb, recolor_strength, recolor_lift);
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	float tint_lum = max(dot(recolor_tint.rgb, vec3(0.299, 0.587, 0.114)), 0.001);
	base = mix(base, recolor_tint.rgb * (lum / tint_lum) * recolor_lift, panel_tint_strength);
	ALBEDO = mix(base, edge_color.rgb, edge * 0.65);
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
	EMISSION = edge_color.rgb * edge * edge_energy;
}
