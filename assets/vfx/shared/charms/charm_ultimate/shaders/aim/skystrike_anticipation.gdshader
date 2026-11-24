shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
void fragment() {
	vec4 target = texture(mask, UV);
	ALBEDO = mix(tint.rgb, vec3(1.0), target.r * 0.42);
	ALPHA = target.a * opacity;
}
