shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform vec4 edge_color : source_color = vec4(1.0);
uniform float age = 0.0;
uniform float sway = 0.07;

void fragment() {
	float tip = smoothstep(0.0, 0.55, UV.x);
	vec2 flow = UV + vec2(0.0, sin(UV.x * 8.0 - age * TAU) * sway * (1.0 - tip));
	vec4 ribbon = texture(mask, flow);
	float strand = smoothstep(0.35, 0.88, ribbon.r) * tip;
	ALBEDO = mix(tint.rgb, edge_color.rgb, strand);
	ALPHA = ribbon.a * opacity * mix(0.58, 1.0, tip);
}
