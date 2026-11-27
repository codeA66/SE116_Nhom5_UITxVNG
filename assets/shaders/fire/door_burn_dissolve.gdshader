shader_type spatial;
render_mode cull_disabled;

// Shader đốt cháy cửa lan tỏa tròn từ tâm ký hiệu lửa ra mép ngoài.
uniform float burn_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 burn_origin = vec2(0.0, 0.05);
uniform float max_radius = 2.95;
uniform float edge_width : hint_range(0.02, 0.5) = 0.16;
uniform float noise_strength : hint_range(0.0, 0.35) = 0.11;
uniform vec4 base_color : source_color = vec4(0.5, 0.25, 0.085, 1.0);
uniform vec4 char_color : source_color = vec4(0.08, 0.04, 0.03, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.28, 0.04, 1.0);
uniform vec4 flame_color : source_color = vec4(1.0, 0.88, 0.35, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 3.2;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.65;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.7;

varying vec3 v_local_pos;

void vertex() {
	v_local_pos = VERTEX;
}

void fragment() {
	if (burn_progress <= 0.001) {
		ALBEDO = base_color.rgb;
		METALLIC = metallic_value;
		ROUGHNESS = roughness_value;
		EMISSION = vec3(0.0);
	} else {
		vec2 delta = v_local_pos.xy - burn_origin;
		float radial = length(delta) / max(max_radius, 0.001);
		float angle = atan(delta.y, delta.x);
		float wave_a = sin(angle * 7.0 + TIME * 4.5 + radial * 6.0);
		float wave_b = cos(angle * 13.0 - TIME * 6.0 + v_local_pos.y * 3.0);
		float wave = (wave_a * 0.6 + wave_b * 0.4) * 0.5 + 0.5;
		float noisy_radial = radial - wave * noise_strength;

		// Mở rộng ngưỡng vượt 1.0 để cháy sạch hoàn toàn cả 4 góc cánh cửa ở cuối tiến trình.
		float threshold = burn_progress * (1.0 + noise_strength + edge_width);
		float edge_dist = noisy_radial - threshold;
		if (edge_dist < 0.0) {
			discard;
		}

		float edge_norm = clamp(edge_dist / max(edge_width, 0.001), 0.0, 1.0);
		float char_band = 1.0 - smoothstep(0.35, 1.0, edge_norm);
		float glow_band = 1.0 - smoothstep(0.0, 0.65, edge_norm);
		float hot_core = 1.0 - smoothstep(0.0, 0.28, edge_norm);

		vec3 surface = mix(base_color.rgb, char_color.rgb, char_band);
		vec3 fire_tint = mix(ember_color.rgb, flame_color.rgb, hot_core);
		ALBEDO = mix(surface, fire_tint, glow_band);
		METALLIC = metallic_value * (1.0 - char_band * 0.85);
		ROUGHNESS = mix(roughness_value, 0.95, char_band);
		EMISSION = fire_tint * glow_band * emission_energy;
	}
}
