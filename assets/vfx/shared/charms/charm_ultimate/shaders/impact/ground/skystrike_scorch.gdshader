shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
void fragment() {
	vec4 ash = texture(mask, UV);
	ALBEDO = tint.rgb * mix(0.51, 1.25, ash.r);
	ALPHA = ash.a * opacity;
}
