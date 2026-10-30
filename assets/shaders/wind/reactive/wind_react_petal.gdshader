shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 gust_direction = vec3(1.0, 0.0, 0.0);
uniform vec3 hold_direction = vec3(1.0, 0.0, 0.0);
uniform float gust_strength = 0.0;
uniform float hold_strength = 0.0;
uniform float gust_progress = 1.0;
uniform float flight_distance = 1.2;
uniform float flight_lift = 1.1;
uniform float flutter_speed = 8.0;

void vertex() {
	float flight = sin(gust_progress * 3.14159265) * gust_strength;
	vec3 travel = normalize(gust_direction + vec3(0.0001, 0.0, 0.0)) * flight_distance * flight;
	VERTEX += travel;
	VERTEX.xz += normalize(hold_direction.xz + vec2(0.0001, 0.0)) * hold_strength * 0.2;
	VERTEX.y += flight_lift * flight + hold_strength * 0.12;
	VERTEX.y += sin(TIME * flutter_speed + VERTEX.x * 2.0 + VERTEX.z * 1.7) * 0.06 * (flight + hold_strength);
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, vec3(0.94, 0.72, 0.8), 0.45);
	ROUGHNESS = 0.85;
}
