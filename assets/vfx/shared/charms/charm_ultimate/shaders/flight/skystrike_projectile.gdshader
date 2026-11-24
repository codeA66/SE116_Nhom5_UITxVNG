shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(1.0);

void fragment() {
	float facet = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = mix(tint.rgb, edge_color.rgb, smoothstep(0.18, 0.88, facet));
}
