shader_type particles;
render_mode disable_velocity, disable_force;

uniform float gather_radius : hint_range(0.02, 1.0) = 0.27;
uniform float gather_depth : hint_range(0.0, 1.0) = 0.24;
uniform float orbit_angle : hint_range(0.0, 3.14) = 1.2;
uniform float spark_size : hint_range(0.01, 0.5) = 0.20;
uniform vec4 charge_color : source_color = vec4(1.0, 0.32, 0.46, 0.78);

void place_spark(inout mat4 transform, inout vec4 custom, inout vec4 color) {
	float age = clamp(custom.y, 0.0, 1.0);
	float remaining = 1.0 - age;
	float angle = custom.z + age * orbit_angle;
	float radius = gather_radius * custom.w * pow(remaining, 0.75);
	transform[3].xyz = vec3(cos(angle) * radius, sin(angle) * radius,
		-gather_depth * custom.w * remaining);
	color = charge_color;
	color.a *= smoothstep(0.0, 0.18, age) * smoothstep(0.0, 0.34, remaining);
}

void start() {
	float seed = float(RANDOM_SEED % 1021u) + float(NUMBER % 2039u);
	float random_angle = fract(sin(seed * 13.713) * 43758.54) * TAU;
	float spread = mix(0.55, 1.0, fract(sin(seed * 2.731) * 12974.5));
	CUSTOM = vec4(random_angle, 0.0, random_angle, spread);
	TRANSFORM[0].xyz *= spark_size * spread;
	TRANSFORM[1].xyz *= spark_size * spread;
	TRANSFORM[2].xyz *= spark_size * spread;
	place_spark(TRANSFORM, CUSTOM, COLOR);
}

void process() {
	CUSTOM.y += DELTA / LIFETIME;
	place_spark(TRANSFORM, CUSTOM, COLOR);
}
