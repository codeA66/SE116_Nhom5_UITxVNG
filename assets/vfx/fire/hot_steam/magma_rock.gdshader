shader_type spatial;
render_mode diffuse_burley;

uniform float heat : hint_range(0.0, 1.0) = 0.12;
varying vec3 rock_position;

void vertex() {
	rock_position = VERTEX;
}

void fragment() {
	vec3 p = rock_position * 3.2;
	float seam = abs(sin(p.x + sin(p.z * 1.7)) * sin(p.y * 1.4 + p.z));
	float cracks = 1.0 - smoothstep(0.015, 0.075, seam);
	vec3 ember = mix(vec3(0.48, 0.07, 0.008), vec3(1.0, 0.34, 0.035), heat);
	ALBEDO = mix(vec3(0.09, 0.065, 0.055), ember, cracks * 0.85);
	EMISSION = ember * cracks * (0.25 + heat * 1.6);
	ROUGHNESS = 0.95;
}
