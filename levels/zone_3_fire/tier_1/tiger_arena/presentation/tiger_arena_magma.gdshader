shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D magma_pattern : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 crust : source_color = vec4(0.15, 0.023, 0.030, 1.0);
uniform vec4 flowing : source_color = vec4(0.75, 0.145, 0.026, 1.0);
uniform vec4 hottest : source_color = vec4(1.0, 0.41, 0.092, 1.0);
uniform vec2 drift = vec2(0.012, 0.0028);

void fragment() {
	vec2 slow_uv = UV + drift * TIME;
	float broad = texture(magma_pattern, slow_uv).r;
	float edges = texture(magma_pattern, UV * 2.4 - drift.yx * TIME * 0.72).g;
	float heat = smoothstep(0.38, 0.91, broad * 0.84 + edges * 0.54);
	vec3 rock_heat = mix(crust.rgb, flowing.rgb, heat);
	ALBEDO = mix(rock_heat, hottest.rgb, smoothstep(0.67, 1.0, heat) * 0.81);
}
