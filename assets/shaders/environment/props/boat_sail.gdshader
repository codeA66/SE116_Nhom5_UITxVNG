shader_type spatial;
render_mode cull_disabled;

uniform vec4 cloth_color : source_color = vec4(0.91, 0.93, 0.91, 1.0);
uniform float deployment : hint_range(0.0, 1.0) = 1.0;
uniform float gust : hint_range(0.0, 1.0) = 0.0;
uniform float flutter_amplitude = 0.045;
uniform float flutter_speed = 3.0;
uniform float sail_top = 3.458;
uniform float sail_bottom = 1.248;
uniform float furled_ratio = 0.06;
uniform bool is_yard = false;

void vertex() {
	float span = max(sail_top - sail_bottom, 0.01);
	float height = clamp((VERTEX.y - sail_bottom) / span, 0.0, 1.0);
	float unfold = mix(furled_ratio, 1.0, deployment);
	if (!is_yard) {
		float envelope = sin(height * PI);
		float ripple = sin(TIME * flutter_speed + VERTEX.x * 3.2 + height * 4.0);
		VERTEX.z += ripple * flutter_amplitude * envelope * (0.2 + deployment + gust * 3.0);
		VERTEX.y = sail_top - (sail_top - VERTEX.y) * unfold;
	} else if (height < 0.5) {
		// Nâng cả thanh ngang dưới, không bóp méo tiết diện thanh gỗ.
		VERTEX.y += span * (1.0 - unfold);
	}
}

void fragment() {
	ALBEDO = cloth_color.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
}
