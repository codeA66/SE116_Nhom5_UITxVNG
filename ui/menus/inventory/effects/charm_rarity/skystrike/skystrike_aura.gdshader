shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D aura_texture : filter_linear, repeat_disable;
uniform vec4 rarity_color : source_color = vec4(0.91, 0.61, 0.29, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.93, 0.75, 1.0);
uniform float glow_strength = 0.88;
uniform float pulse_speed = 0.38;
uniform float selected = 0.0;
uniform float opening = 0.0;

vec3 feather_stroke(vec2 p, vec2 root, vec2 tip, float width) {
	vec2 reach = tip - root;
	float along = clamp(dot(p - root, reach) / dot(reach, reach), 0.0, 1.0);
	float edge = length(p - root - reach * along);
	float belly = width * (0.18 + 0.82 * sin(along * PI)) * (1.0 - along * 0.42);
	float cap = smoothstep(0.0, 0.16, along) * (1.0 - smoothstep(0.90, 1.0, along));
	float fill = (1.0 - smoothstep(belly - 0.022, belly + 0.022, edge)) * cap;
	float rim = smoothstep(0.65, 0.94, edge / max(belly, 0.01)) * fill;
	float shaft = (1.0 - smoothstep(0.013, 0.034, edge)) * cap;
	return vec3(fill, rim, shaft);
}

vec3 angel_wing(vec2 p, float spread) {
	// Dùng chung dáng lông hai bên để cánh bung từ sau huy hiệu trong cùng một nhịp.
	p.x = 0.40 + (abs(p.x) - 0.40) / mix(0.46, 1.0, spread);
	p.y -= (1.0 - spread) * (p.x - 0.40) * 0.76;
	vec3 crest = feather_stroke(p, vec2(0.38, 0.06), vec2(0.96, -0.88), 0.136);
	vec3 flight = feather_stroke(p, vec2(0.38, 0.15), vec2(1.00, -0.57), 0.123);
	vec3 cover = feather_stroke(p, vec2(0.34, 0.24), vec2(0.96, -0.27), 0.108);
	vec3 tuft = feather_stroke(p, vec2(0.30, 0.32), vec2(0.86, 0.05), 0.094);
	return max(max(crest, flight), max(cover, tuft));
}

void fragment() {
	vec4 modulation = COLOR;
	vec2 p = UV * 2.0 - 1.0;
	float angle = TIME * pulse_speed;
	vec2 across = vec2(cos(angle), sin(angle));
	vec2 rotated = vec2(dot(p, across), dot(p, vec2(-across.y, across.x)));
	vec4 foil = texture(aura_texture, rotated * 0.5 + 0.5);
	vec4 frame = texture(aura_texture, UV);
	float r = length(p);
	float entry_r = mix(0.96, 0.69, opening);
	float ripple = (1.0 - smoothstep(0.012, 0.038, abs(r - entry_r))) * opening * 0.75;
	float band = foil.r * (0.76 + 0.16 * sin(angle * 2.3)) + frame.b * 0.58;
	float halo = frame.g * (0.44 + selected * 0.18);
	float edge = 1.0 - smoothstep(0.94, 1.0, r);
	float ring_alpha = clamp((band + halo + ripple) * glow_strength * (1.0 + selected * 0.20), 0.0, 1.0) * edge;
	vec3 ring = mix(rarity_color.rgb, highlight_color.rgb, clamp(band * 0.86 + ripple, 0.0, 1.0));
	float spread = smoothstep(0.0, 0.92, 1.0 - opening);
	vec3 feather = angel_wing(p, spread);
	float gold_sweep = pow(max(cos(p.y * 5.0 - angle * 2.4), 0.0), 3.0);
	float margin = 1.0 - smoothstep(0.966, 1.0, max(abs(p.x), abs(p.y)));
	float wing_alpha = clamp((feather.x * 0.68 + feather.y * gold_sweep * 0.20 + feather.z * 0.18)
		* glow_strength * mix(0.15, 1.0, spread) * (1.0 + selected * 0.12) * margin, 0.0, 1.0);
	vec3 ivory = mix(highlight_color.rgb, vec3(1.0, 0.985, 0.93), 0.66);
	vec3 wing = mix(ivory, rarity_color.rgb, feather.y * (0.36 + gold_sweep * 0.38));
	// Ánh viền phủ lên gốc cánh để hình bùa vẫn là điểm sáng chính.
	float under_ring = wing_alpha * (1.0 - ring_alpha);
	float opacity = ring_alpha + under_ring;
	vec3 ink = (ring * ring_alpha + wing * under_ring) / max(opacity, 0.0001);
	COLOR = vec4(ink * modulation.rgb, opacity * modulation.a);
}
