shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, world_vertex_coords;

uniform vec4 tint : source_color = vec4(0.36, 0.85, 0.67, 1.0);
uniform float appearance : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

varying vec3 surface_point;

void vertex() {
	surface_point = VERTEX - NODE_POSITION_WORLD;
}

float grain(vec3 point) {
	return fract(sin(dot(point, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 1.75);
	float folds = sin(surface_point.y * 9.0 + surface_point.x * 3.0 - TIME * 2.9);
	float threads = 0.5 + 0.5 * sin(surface_point.y * 24.0 + folds * 1.6 - TIME * 4.0);
	vec3 cell = floor(surface_point * 18.0);
	float erosion = mix(0.28 + facing * 0.44, grain(cell), 0.27) + folds * 0.055;
	float edge = smoothstep(-0.005, 0.075, erosion - dissolve) *
		(1.0 - smoothstep(0.075, 0.16, erosion - dissolve));
	float body = smoothstep(-0.025, 0.045, erosion - dissolve);
	vec3 shade = mix(tint.rgb * 0.31, tint.rgb, rim * 0.74 + threads * 0.16);
	shade = mix(shade, vec3(0.92, 1.0, 0.98), clamp(rim * 0.44 + edge * 0.85, 0.0, 1.0));
	ALBEDO = shade;
	ALPHA = body * appearance * (0.30 + rim * 0.42 + edge * 0.21 + threads * 0.09);
}
