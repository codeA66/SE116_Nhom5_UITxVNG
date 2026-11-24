shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(1.0);

void fragment() {
	float tip = smoothstep(0.10, 0.72, UV.y);
	ALBEDO = mix(tint.rgb, edge_color.rgb, tip * 0.73) * COLOR.rgb;
	ALPHA = COLOR.a * (0.35 + tip * 0.65);
}
