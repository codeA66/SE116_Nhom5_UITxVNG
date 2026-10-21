shader_type spatial;
// Toon 2 bậc sáng/tối cho Foxy, bóng ngả tím ấm và viền sáng nhẹ (giống bản Blender)
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.60, 0.50, 0.66, 1.0);
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;
uniform float softness : hint_range(0.001, 0.5) = 0.06;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = albedo.rgb * rim * rim_strength;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(threshold, threshold + softness, ndl) * smoothstep(0.2, 0.5, ATTENUATION);
	vec3 band = mix(shadow_tint.rgb * 0.45, vec3(1.0), lit);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI * 0.9;
}
