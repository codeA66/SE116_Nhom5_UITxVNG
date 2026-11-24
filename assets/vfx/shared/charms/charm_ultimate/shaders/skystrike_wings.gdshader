shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform float scroll = 0.0;
uniform float scroll_depth = 0.17;

void fragment() {
	float side = abs(UV.y * 2.0 - 1.0);
	float shaft = 1.0 - smoothstep(0.24, 0.88, side);
	float pulse = (0.5 + 0.5 * sin((UV.x - scroll) * TAU)) * scroll_depth;
	vec3 vane = mix(tint.rgb, edge_color.rgb, shaft * 0.86 + pulse);
	ALBEDO = vane * mix(0.40, 1.0, opacity);
}
