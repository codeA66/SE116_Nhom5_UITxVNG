shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float ripple = sin(UV.x * 100.0 + TIME * 1.3 + sin(UV.y * 70.0)) * 0.5 + 0.5;
	float glint = pow(ripple, 16.0) * 0.055;
	ALBEDO = vec3(0.055, 0.17, 0.19) + vec3(glint);
	ROUGHNESS = 0.25;
	SPECULAR = 0.5;
}
