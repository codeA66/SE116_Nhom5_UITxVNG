shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.36, 0.85, 0.67, 1.0);

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(1.0 - facing, 0.56);
	float center = pow(facing, 5.0);
	float current = sin(UV.y * 37.0 + sin(UV.x * 17.0 - TIME * 2.0) * 1.55 - TIME * 4.7);
	float threads = smoothstep(0.46, 0.99, current) * facing;
	vec3 tint_body = mix(tint.rgb * 0.38, tint.rgb, 0.33 + threads * 0.50);
	vec3 tint_rim = mix(tint.rgb, vec3(0.90, 1.0, 0.98), edge * 0.38);
	ALBEDO = mix(mix(tint_body, tint_rim, edge), vec3(0.96, 1.0, 0.99), center * 0.75);
	ALPHA = 0.69 + center * 0.29 + edge * 0.14;
}
