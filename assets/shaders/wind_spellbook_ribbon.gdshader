shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 wind_color : source_color = vec4(0.65, 0.88, 0.94, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.72;
uniform float orbit_speed = 0.8;
uniform float float_amplitude = 0.065;
uniform float float_speed = 1.5;

void vertex() {
	float angle = TIME * orbit_speed;
	mat3 turn = mat3(vec3(cos(angle), 0.0, -sin(angle)), vec3(0.0, 1.0, 0.0), vec3(sin(angle), 0.0, cos(angle)));
	VERTEX = turn * VERTEX;
	VERTEX.y += sin(TIME * float_speed) * float_amplitude;
}

void fragment() {
	float edge = 1.0 - pow(abs(UV.y * 2.0 - 1.0), 2.0);
	float taper = pow(max(sin(UV.x * PI), 0.0), 0.7);
	ALBEDO = mix(wind_color.rgb, vec3(0.92, 0.98, 1.0), edge * 0.45);
	ALPHA = edge * taper * opacity;
}
