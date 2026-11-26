shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 edge_color : source_color = vec4(0.66, 0.91, 1.0, 1.0);
uniform vec4 void_color : source_color = vec4(0.036, 0.09, 0.16, 1.0);
uniform float opening : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float opened = smoothstep(0.28, 0.78, opening);
	float crack_light = smoothstep(0.02, 0.20, opening) * (1.0 - smoothstep(0.28, 0.72, opening));
	float flash = smoothstep(0.36, 0.48, opening) * (1.0 - smoothstep(0.48, 0.69, opening));
	float curve = sin(p.y * 8.0 - 0.6) * 0.042 + sin(p.y * 18.0 + 0.7) * 0.022;
	float x = (p.x - curve) / mix(0.045, 0.84, opened);
	float r = length(vec2(x, p.y * 1.04));
	float face = 1.0 - smoothstep(0.88, 1.0, r);
	float edge = 1.0 - smoothstep(0.021, 0.068, abs(r - 0.93));
	float haze = (1.0 - smoothstep(0.01, 0.25, abs(r - 0.93))) * (0.36 + flash * 0.46);
	float curl = sin(atan(p.y, x) * 4.0 + r * 13.5 - TIME * 2.2 + sin(p.y * 7.0));
	float stream = smoothstep(0.64, 0.97, curl) * face * smoothstep(0.11, 0.95, r);
	float crack = (1.0 - smoothstep(0.012, 0.068, abs(p.x - curve))) *
		(1.0 - smoothstep(0.44, 0.94, abs(p.y))) * crack_light;
	float running_light = pow(max(0.0, sin(p.y * 9.0 - TIME * 3.2)), 9.0) * edge;
	float ripple = (1.0 - smoothstep(0.008, 0.06, abs(r - 0.70 - (1.0 - flash) * 0.16))) * flash;
	vec3 phase_color = mix(void_color.rgb, edge_color.rgb, clamp(edge * 0.84 + haze + stream * 0.31, 0.0, 1.0));
	ALBEDO = mix(phase_color, vec3(0.95, 0.99, 1.0), clamp(crack + ripple * 0.8 + edge * 0.20 + running_light * 0.52, 0.0, 1.0));
	ALPHA = max(max(face * 0.86, edge), max(haze * 0.54, max(crack, ripple))) * smoothstep(0.0, 0.13, opening);
}
