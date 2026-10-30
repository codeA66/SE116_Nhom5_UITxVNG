// Đốm lửa đỏ bay vào từ mép màn hình (CPUParticles2D không texture): vòng sáng mềm, lõi nóng.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 0.2, 0.12, 1.0);

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float a = pow(1.0 - smoothstep(0.0, 1.0, r), 1.5);
	COLOR = vec4(mix(tint.rgb, vec3(1.0, 0.8, 0.6), a * a), a * COLOR.a);
}
