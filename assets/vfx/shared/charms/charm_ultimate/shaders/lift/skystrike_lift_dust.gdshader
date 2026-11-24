shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform float age = 0.0;

void fragment() {
	vec2 offset = UV - 0.5;
	float radius = length(offset);
	vec4 grain = texture(mask, UV);
	float outward = smoothstep(0.02, 0.22, radius + age * 0.23);
	ALBEDO = tint.rgb * mix(0.63, 1.1, grain.r);
	ALPHA = grain.a * outward * opacity;
}
