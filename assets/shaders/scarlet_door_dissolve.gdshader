shader_type spatial;
render_mode cull_disabled;

uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.14, 0.08, 1.0);
uniform float edge_width : hint_range(0.01, 0.15) = 0.055;
uniform float edge_energy : hint_range(0.0, 4.0) = 1.8;
varying vec3 object_position;

float cell_noise(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	object_position = VERTEX;
}

void fragment() {
	float radial = distance(object_position.xy, vec2(0.0, 1.58)) / 3.2;
	float pattern = radial * 0.72 + cell_noise(floor(object_position * 7.0)) * 0.28;
	float threshold = dissolve * 1.4 - 0.2;
	if (pattern < threshold) {
		discard;
	}
	float edge = (1.0 - smoothstep(threshold, threshold + edge_width, pattern)) * step(0.01, dissolve);
	ALBEDO = mix(COLOR.rgb, edge_color.rgb, edge * 0.65);
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
	EMISSION = edge_color.rgb * edge * edge_energy;
}
