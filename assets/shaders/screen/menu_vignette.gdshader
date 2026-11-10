shader_type canvas_item;
// Viền tối quanh màn hình menu + tối thêm phía dưới để chữ luôn đọc được trên nền 3D sáng.

uniform vec4 shade_color : source_color = vec4(0.03, 0.035, 0.05, 1.0);
uniform float edge_strength : hint_range(0.0, 1.0) = 0.75;
uniform float inner_radius : hint_range(0.0, 1.5) = 0.35;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.05;
uniform float base_dim : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	vec2 centered = (UV - 0.5) * vec2(1.6, 1.0);
	float edge = smoothstep(inner_radius, outer_radius, length(centered));
	float alpha = clamp(base_dim + edge * edge_strength, 0.0, 1.0);
	COLOR = vec4(shade_color.rgb, alpha * shade_color.a);
}
