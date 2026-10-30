shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 active_color : source_color = vec4(0.34, 0.7, 0.79, 1.0);
uniform float active_level : hint_range(0.0, 1.0) = 0.0;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.6;
uniform float center_tint : hint_range(0.0, 1.0) = 0.4;
uniform float platform_radius = 0.925;
varying float facet_shade;
varying vec2 stone_position;

void vertex() {
	// Giữ độ chênh sáng giữa mặt trên và cạnh đá khi phủ màu kích hoạt.
	facet_shade = 0.62 + 0.38 * max(NORMAL.y, 0.0);
	stone_position = VERTEX.xz;
}

void fragment() {
	ALBEDO = active_color.rgb * facet_shade;
	float rim = smoothstep(0.15, 1.0, length(stone_position) / platform_radius);
	ALPHA = active_level * tint_strength * mix(center_tint, 1.0, rim);
}
