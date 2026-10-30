shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

global uniform float wind_react_clock;

uniform vec4 cloth_white : source_color = vec4(0.94, 0.98, 1.0, 1.0);
uniform vec4 cloth_blue : source_color = vec4(0.48, 0.78, 0.91, 1.0);
uniform vec3 gust_direction = vec3(0.0, 0.0, 1.0);
uniform vec3 hold_direction = vec3(0.0, 0.0, 1.0);
uniform float gust_strength = 0.0;
uniform float hold_strength = 0.0;
uniform float gust_time = -100.0;
uniform float recovery_seconds = 1.4;
uniform float flutter_speed = 8.0;
uniform float cloth_sway = 0.4;

void vertex() {
	float age = max(wind_react_clock - gust_time, 0.0);
	float gust = age < recovery_seconds ? gust_strength * exp(-age * 4.0 / max(recovery_seconds, 0.01)) : 0.0;
	vec2 airflow = gust_direction.xz * gust + hold_direction.xz * hold_strength;
	float wind = min(length(airflow), 2.0);
	vec2 airflow_dir = normalize(airflow + vec2(0.0001, 0.0));
	float tether = UV.x * UV.x;
	float wave = sin(TIME * flutter_speed + UV.x * 11.0 - UV.y * 2.0) * wind * cloth_sway * tether;
	VERTEX.xz += airflow_dir * wind * 0.26 * tether;
	VERTEX.z += wave;
	VERTEX.y += sin(TIME * flutter_speed * 0.8 + UV.x * 7.0) * wind * 0.08 * tether;
}

void fragment() {
	float band = step(0.5, UV.y);
	ALBEDO = mix(cloth_white.rgb, cloth_blue.rgb, band);
	ALPHA = 1.0;
}
