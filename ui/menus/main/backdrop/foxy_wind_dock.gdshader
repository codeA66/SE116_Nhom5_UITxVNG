shader_type canvas_item;

uniform float scarf_lift : hint_range(0.0, 0.02) = 0.012;
uniform float banner_sway : hint_range(0.0, 0.02) = 0.009;
uniform float gust_interval : hint_range(1.0, 12.0) = 5.2;
uniform float banner_delay : hint_range(0.0, 2.0) = 0.45;
uniform float fog_strength : hint_range(0.0, 0.2) = 0.11;
uniform float fog_speed : hint_range(0.0, 0.15) = 0.04;
uniform float lantern_strength : hint_range(0.0, 0.3) = 0.085;

float ellipse_mask(vec2 uv, vec2 center, vec2 radius) {
	vec2 scaled = (uv - center) / radius;
	return 1.0 - smoothstep(0.18, 1.0, dot(scaled, scaled));
}

float gust(float time) {
	float phase = fract(time / gust_interval);
	return smoothstep(0.02, 0.26, phase) * (1.0 - smoothstep(0.30, 0.74, phase));
}

void fragment() {
	vec2 uv = UV;
	vec2 sample_uv = uv;
	// Giảm lực về sát cổ để giữ nguyên dáng đứng của Foxy.
	float scarf = ellipse_mask(uv, vec2(0.622, 0.641), vec2(0.055, 0.045));
	float scarf_tip = 1.0 - smoothstep(0.604, 0.693, uv.x);
	float ripple = sin(TIME * 3.4 + uv.x * 52.0);
	sample_uv.y += scarf_lift * scarf * scarf_tip * (gust(TIME) * (0.78 + 0.22 * ripple) + 0.09 * ripple);

	// Giữ chân cờ và vòm đá đứng yên trong lúc mép vải lay.
	float left_banner = ellipse_mask(uv, vec2(0.607, 0.133), vec2(0.047, 0.090));
	float right_banner = ellipse_mask(uv, vec2(0.690, 0.162), vec2(0.057, 0.116));
	float banner_tip = smoothstep(0.045, 0.190, uv.y);
	float banner_time = TIME - banner_delay;
	float banner_wave = 0.7 * gust(banner_time) + 0.3 * sin(banner_time * 2.7 - uv.y * 31.0);
	sample_uv.x -= banner_sway * banner_tip * banner_wave * max(left_banner * 0.76, right_banner);
	vec3 art = texture(TEXTURE, sample_uv).rgb;

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
