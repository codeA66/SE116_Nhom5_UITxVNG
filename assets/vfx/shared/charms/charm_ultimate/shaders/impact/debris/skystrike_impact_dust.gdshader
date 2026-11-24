shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
void vertex() {
	vec3 scale_by = vec3(length(MODELVIEW_MATRIX[0].xyz), length(MODELVIEW_MATRIX[1].xyz), length(MODELVIEW_MATRIX[2].xyz));
	MODELVIEW_MATRIX[0] = vec4(scale_by.x, 0.0, 0.0, 0.0);
	MODELVIEW_MATRIX[1] = vec4(0.0, scale_by.y, 0.0, 0.0);
	MODELVIEW_MATRIX[2] = vec4(0.0, 0.0, scale_by.z, 0.0);
}
void fragment() {
	vec4 puff = texture(mask, UV);
	ALBEDO = mix(tint.rgb * 0.64, tint.rgb * 1.2, puff.r) * COLOR.rgb;
	ALPHA = puff.a * COLOR.a * opacity;
}
