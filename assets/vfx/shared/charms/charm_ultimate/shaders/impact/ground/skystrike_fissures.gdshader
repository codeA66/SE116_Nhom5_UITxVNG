shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Vết nứt nóng: gần tâm trắng nóng, ra xa cam, nguội dần theo thời gian (heat 1 -> 0); mép nguội trước tâm.
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform vec4 edge_color : source_color = vec4(1.0);
// Màu lõi nóng nhất ở tâm
uniform vec4 hot_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);
uniform float reveal = 0.0;
uniform float heat = 1.0;

void fragment() {
	vec4 line = texture(mask, UV);
	float r = length(UV * 2.0 - 1.0);
	float reach = 1.0 - smoothstep(reveal, reveal + 0.13, r);
	float local = clamp(heat * 1.35 - r * 0.85, 0.0, 1.0);
	vec3 color = mix(tint.rgb * 0.55, tint.rgb, smoothstep(0.0, 0.35, local));
	color = mix(color, edge_color.rgb, smoothstep(0.3, 0.7, local) * line.r);
	color = mix(color, hot_color.rgb, smoothstep(0.7, 1.0, local) * line.r);
	ALBEDO = color;
	ALPHA = line.a * reach * opacity * mix(0.12, 0.95, local);
}
