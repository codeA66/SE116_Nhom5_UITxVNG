shader_type spatial;
render_mode shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(0.34, 0.30, 0.27, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.4, 0.15, 1.0);
uniform float heat = 1.0;

void fragment() {
	float face = smoothstep(0.13, 0.85, abs(normalize(NORMAL).y));
	ALBEDO = mix(tint.rgb * 0.58, tint.rgb * 1.30, face);
	ROUGHNESS = 1.0;
	EMISSION = edge_color.rgb * heat * (1.0 - face) * 0.24;
}
