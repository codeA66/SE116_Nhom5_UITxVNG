shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D aura_texture : filter_linear, repeat_disable;
uniform vec4 rarity_color : source_color = vec4(0.91, 0.61, 0.29, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.93, 0.75, 1.0);
uniform float glow_strength = 0.88;
uniform float pulse_speed = 0.38;
uniform float selected = 0.0;
uniform float opening = 0.0;

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
	float opacity = clamp((band + halo + ripple) * glow_strength * (1.0 + selected * 0.20), 0.0, 1.0);
	COLOR = vec4(mix(rarity_color.rgb, highlight_color.rgb, clamp(band * 0.86 + ripple, 0.0, 1.0)) * modulation.rgb,
		opacity * edge * modulation.a);
}
