shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform vec4 edge_color : source_color = vec4(1.0);
uniform float remaining = 1.0;
uniform float rotation = 0.0;
uniform float edge_width = 0.025;
uniform float fill_alpha = 0.36;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float theta = atan(p.y, p.x);
	float clockwise = fract(theta / TAU + 0.25);
	float ticks = smoothstep(0.86, 0.97, cos(theta * 12.0 - rotation));
	ticks *= smoothstep(0.78, 0.86, r) * (1.0 - smoothstep(0.91, 0.94, r));
	float edge = 1.0 - smoothstep(edge_width * 0.44, edge_width, abs(r - (0.99 - edge_width)));
	float time_slice = (1.0 - smoothstep(remaining - 0.01, remaining, clockwise)) * step(0.001, remaining);
	float fill = texture(mask, UV).a * time_slice;
	ALBEDO = mix(tint.rgb, edge_color.rgb, max(edge, ticks));
	ALPHA = clamp(max(fill * fill_alpha, max(edge * 0.92, ticks)) * opacity, 0.0, 1.0);
}
