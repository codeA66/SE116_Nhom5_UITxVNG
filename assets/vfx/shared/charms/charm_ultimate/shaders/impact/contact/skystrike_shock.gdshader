shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform vec4 edge_color : source_color = vec4(1.0);
uniform float front = 0.06;
uniform float band_width = 0.21;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ratio = r / max(front, 0.001);
	vec4 grain = texture(mask, 0.5 + p * (0.43 / max(front, 0.001)));
	float thickness = band_width * mix(0.67, 1.0, grain.a);
	float body = smoothstep(1.0 - thickness, 1.0 - thickness * 0.62, ratio);
	// Chặn ngay mép bán kính để hình khớp vùng sát thương.
	body *= 1.0 - smoothstep(0.972, 1.0, ratio);
	float crest = smoothstep(0.86, 0.964, ratio);
	ALBEDO = mix(tint.rgb, edge_color.rgb, crest * 0.48);
	ALPHA = body * opacity * mix(0.63, 1.0, grain.a);
}
