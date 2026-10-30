shader_type spatial;

uniform vec4 dormant_color : source_color = vec4(0.545, 0.584, 0.588, 1.0);
uniform vec4 active_color : source_color = vec4(0.945, 0.965, 0.957, 1.0);
uniform vec4 edge_color : source_color = vec4(0.82, 0.929, 0.949, 1.0);
uniform float active_level : hint_range(0.0, 1.0) = 0.0;
uniform float emission_energy = 0.65;
uniform float edge_energy = 1.1;
uniform float edge_width = 1.0;
uniform float spin_speed = 0.20944;
uniform float float_amplitude = 0.035;
uniform float float_speed = 1.4;

void vertex() {
	float angle = TIME * spin_speed;
	mat3 turn = mat3(vec3(cos(angle), 0.0, -sin(angle)), vec3(0.0, 1.0, 0.0), vec3(sin(angle), 0.0, cos(angle)));
	VERTEX = turn * VERTEX;
	NORMAL = turn * NORMAL;
	VERTEX.y += sin(TIME * float_speed) * float_amplitude;
}

void fragment() {
	// UV tam giác giữ nét sáng đúng trên cạnh hình học, không cần texture ngoài.
	// glTF đảo trục V của UV Blender khi xuất.
	float barycentric = min(min(UV.x, 1.0 - UV.y), UV.y - UV.x);
	float edge = 1.0 - smoothstep(0.0, max(fwidth(barycentric) * edge_width, 0.0001), barycentric);
	float breath = 0.96 + sin(TIME * 1.3) * 0.04;
	ALBEDO = mix(dormant_color.rgb, active_color.rgb * 0.45, active_level * 0.78);
	EMISSION = active_level * breath * (active_color.rgb * emission_energy * 0.14 + edge_color.rgb * edge * edge_energy);
	ROUGHNESS = mix(0.95, 0.72, active_level);
	SPECULAR = 0.15;
}
