shader_type canvas_item;

uniform float wind_strength : hint_range(0.0, 0.02) = 0.006;
uniform float fog_strength : hint_range(0.0, 0.2) = 0.075;
uniform float lantern_strength : hint_range(0.0, 0.3) = 0.16;

float ellipse_mask(vec2 uv, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.0, 1.0, length((uv - center) / radius));
}

void fragment() {
	vec2 uv = UV;
	// Giữ vai cáo đứng yên khi đầu khăn đung đưa.
	float scarf = ellipse_mask(uv, vec2(0.628, 0.638), vec2(0.054, 0.043));
	float banners = ellipse_mask(uv, vec2(0.657, 0.157), vec2(0.104, 0.12));
	uv.y += wind_strength * scarf * sin(TIME * 2.2 + uv.x * 42.0);
	uv.x += wind_strength * 0.65 * banners * sin(TIME * 1.45 + uv.y * 21.0);
	vec3 art = texture(TEXTURE, uv).rgb;

	float drift = sin(uv.x * 18.0 - TIME * 0.45 + sin(uv.y * 31.0));
	float mist = ellipse_mask(uv, vec2(0.85, 0.59 + drift * 0.034), vec2(0.38, 0.11));
	float foreground = max(
		ellipse_mask(uv, vec2(0.70, 0.65), vec2(0.095, 0.20)),
		ellipse_mask(uv, vec2(0.47, 0.54), vec2(0.075, 0.35))
	);
	art = mix(art, vec3(0.68, 0.84, 0.87), mist * (1.0 - foreground) * fog_strength);

	float flicker = 0.5 + 0.32 * sin(TIME * 3.1) + 0.18 * sin(TIME * 7.3);
	float lamp = ellipse_mask(uv, vec2(0.597, 0.322), vec2(0.093, 0.14));
	art += vec3(1.0, 0.56, 0.22) * lamp * lamp * lantern_strength * flicker;
	COLOR = vec4(art, 1.0);
}
