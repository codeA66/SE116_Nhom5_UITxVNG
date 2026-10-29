shader_type spatial;
render_mode cull_disabled;
varying vec3 bary;
varying float crystal_height;
void vertex() { bary = COLOR.rgb; crystal_height = UV.y; }
void fragment() {
	vec3 width = max(fwidth(bary), vec3(0.0001));
	vec3 interior = smoothstep(vec3(0.0), width * 0.65, bary);
	float edge = 1.0 - min(interior.x, min(interior.y, interior.z));
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.5);
	vec3 ice = mix(vec3(0.18, 0.50, 0.76), vec3(0.65, 0.91, 1.0), clamp(crystal_height * 0.65 + 0.25, 0.0, 1.0));
	ALBEDO = mix(ice, vec3(0.78, 0.97, 1.0), edge * 0.55 + rim * 0.18);
	EMISSION = ice * 0.2 + vec3(0.35, 0.8, 1.0) * (edge * 0.55 + rim * 0.2);
	ROUGHNESS = 0.18;
	METALLIC = 0.18;
}
