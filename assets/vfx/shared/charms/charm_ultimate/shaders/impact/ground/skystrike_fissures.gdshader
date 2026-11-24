shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform vec4 edge_color : source_color = vec4(1.0);
uniform float reveal = 0.0;
uniform float heat = 1.0;

void fragment() {
	vec4 line = texture(mask, UV);
	float r = length(UV * 2.0 - 1.0);
	float reach = 1.0 - smoothstep(reveal, reveal + 0.13, r);
	ALBEDO = mix(tint.rgb, edge_color.rgb, line.r * heat * heat);
	ALPHA = line.a * reach * opacity * mix(0.18, 0.74, heat);
}
