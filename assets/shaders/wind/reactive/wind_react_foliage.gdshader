shader_type spatial;
render_mode cull_disabled, shadows_disabled;

global uniform float wind_react_clock;

uniform vec4 tint : source_color = vec4(0.45, 0.66, 0.32, 1.0);
uniform vec3 gust_direction = vec3(1.0, 0.0, 0.0);
uniform vec3 hold_direction = vec3(1.0, 0.0, 0.0);
uniform float gust_strength = 0.0;
uniform float gust_time = -100.0;
uniform float recovery_seconds = 1.4;
uniform float bend_amount = 0.7;
uniform float flutter_speed = 8.0;
uniform float hold_strength = 0.0;
uniform float anchor_height = 0.0;
uniform float foliage_height = 1.0;
uniform float flutter_factor = 0.15;

void vertex() {
	float height_ratio = clamp((VERTEX.y - anchor_height) / max(foliage_height, 0.001), 0.0, 1.0);
	float age = max(wind_react_clock - gust_time, 0.0);
	float gust = age < recovery_seconds ? gust_strength * exp(-age * 4.0 / max(recovery_seconds, 0.01)) : 0.0;
	vec2 wind_vector = gust_direction.xz * gust + hold_direction.xz * hold_strength;
	float wind = min(length(wind_vector), 2.0);
	float bend = wind * bend_amount * height_ratio * height_ratio;
	float flutter = sin(TIME * flutter_speed + VERTEX.x * 3.1 + VERTEX.z * 2.7) * flutter_factor * wind * height_ratio;
	VERTEX.xz += normalize(wind_vector + vec2(0.0001, 0.0)) * (bend + flutter);
}

void fragment() {
	ALBEDO = tint.rgb * COLOR.rgb;
	ROUGHNESS = 0.85;
}
