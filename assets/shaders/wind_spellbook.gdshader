shader_type spatial;
render_mode unshaded;

uniform vec4 book_color : source_color = vec4(1.0);
uniform float brightness : hint_range(0.1, 1.0) = 0.95;
uniform float float_amplitude = 0.065;
uniform float float_speed = 1.5;
uniform float emblem_glow = 0.0;
varying float facet_shade;

void vertex() {
	VERTEX.y += sin(TIME * float_speed) * float_amplitude;
	// Giữ biểu tượng rõ trong map sáng, vẫn có sắc độ giữa các mặt vát.
	vec3 face_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	facet_shade = 0.72 + 0.28 * max(dot(face_normal, normalize(vec3(-0.3, 0.8, 0.7))), 0.0);
}

void fragment() {
	ALBEDO = book_color.rgb * brightness * facet_shade;
	EMISSION = vec3(0.82, 0.95, 0.98) * emblem_glow;
	ROUGHNESS = 0.86;
	SPECULAR = 0.12;
}
