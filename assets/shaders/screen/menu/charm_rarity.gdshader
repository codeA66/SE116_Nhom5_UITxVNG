shader_type canvas_item;
render_mode unshaded;

uniform vec4 rarity_color : source_color = vec4(0.737, 0.596, 0.929, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.941, 0.831, 1.0);
uniform float glow_strength = 0.65;
uniform float pulse_speed = 0.35;
uniform int sparkle_count = 3;
uniform float sparkle_size = 0.10;
uniform float selected = 0.0;

void fragment() {
	vec4 modulation = COLOR;
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float clock = TIME * pulse_speed * TAU;
	float breath = 0.78 + 0.22 * sin(clock);
	float distance_to_rim = abs(radius - 0.8);
	float haze = exp(-distance_to_rim * distance_to_rim * 90.0) * 0.28;
	float rim = exp(-distance_to_rim * distance_to_rim * 4200.0) * 0.65;
	float sweep = pow(max(cos(atan(p.y, p.x) - clock * 0.45), 0.0), 18.0);
	float halo = (haze + rim * (0.6 + sweep * 0.8)) * breath;
	float stars = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= sparkle_count || sparkle_size <= 0.0) {
			break;
		}
		float seed = float(i) * 2.39996 + 0.5;
		vec2 anchor = vec2(cos(seed), sin(seed)) * (0.83 + sin(clock * 0.6 + seed) * 0.03);
		vec2 q = abs(p - anchor) / max(sparkle_size, 0.0001);
		float cross_light = exp(-q.x * 16.0 - q.y * 2.5) + exp(-q.y * 16.0 - q.x * 2.5);
		float flicker = pow(max(sin(clock * 1.1 + seed * 2.0), 0.0), 6.0);
		stars += cross_light * (0.12 + flicker * 0.88);
	}
	float margin = 1.0 - smoothstep(0.96, 1.0, radius);
	float alpha = (halo + stars) * glow_strength * (1.0 + selected * 0.18) * margin;
	COLOR = vec4(mix(rarity_color.rgb, highlight_color.rgb, clamp(stars + sweep * rim, 0.0, 1.0)) * modulation.rgb, clamp(alpha, 0.0, 1.0) * modulation.a);
}
