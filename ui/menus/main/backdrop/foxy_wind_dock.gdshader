shader_type canvas_item;

uniform float fog_strength : hint_range(0.0, 0.2) = 0.11;
uniform float fog_speed : hint_range(0.0, 0.15) = 0.04;
uniform float lantern_strength : hint_range(0.0, 0.3) = 0.085;

float ellipse_mask(vec2 uv, vec2 center, vec2 radius) {
	vec2 scaled = (uv - center) / radius;
	return 1.0 - smoothstep(0.18, 1.0, dot(scaled, scaled));
}

void fragment() {
	vec2 uv = UV;
	// Khăn và cờ là lớp riêng (dock/cloth_wave): nền này chỉ còn sương trôi và đèn lồng
	vec3 art = texture(TEXTURE, uv).rgb;

	// Hai dải trôi lệch tốc độ để sương có chiều sâu sau bến.
	float drift = uv.x - TIME * fog_speed;
	float upper_band = ellipse_mask(uv, vec2(0.842, 0.518), vec2(0.218, 0.069));
	float lower_band = ellipse_mask(uv, vec2(0.901, 0.646), vec2(0.199, 0.070));
	float upper_wisp = smoothstep(-0.65, 0.95, sin(drift * 26.0 + uv.y * 22.0) + 0.35 * sin(drift * 55.0 - uv.y * 34.0));
	float lower_wisp = smoothstep(-0.65, 0.95, sin((uv.x - TIME * fog_speed * 1.65) * 34.0 - uv.y * 20.0));
	float behind_foxy = smoothstep(0.83, 1.18, length((uv - vec2(0.700, 0.644)) / vec2(0.087, 0.154)));
	float mist = max(upper_band * upper_wisp, lower_band * lower_wisp) * behind_foxy;
	art = mix(art, vec3(0.69, 0.82, 0.84), mist * fog_strength);

	float flicker = 0.58 + 0.12 * sin(TIME * 2.3) + 0.06 * sin(TIME * 5.7);
	float lamp = ellipse_mask(uv, vec2(0.597, 0.322), vec2(0.074, 0.108));
	art += vec3(1.0, 0.56, 0.22) * lamp * lamp * lantern_strength * flicker;
	COLOR = vec4(art, 1.0);
}
