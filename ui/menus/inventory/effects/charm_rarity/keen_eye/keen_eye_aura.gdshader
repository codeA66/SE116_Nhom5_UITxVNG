shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D aura_texture : filter_linear, repeat_disable;
uniform vec4 rarity_color : source_color = vec4(0.69, 0.79, 0.47, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.88, 0.55, 1.0);
uniform float glow_strength = 0.83;
uniform float pulse_speed = 0.34;
uniform float selected = 0.0;
uniform float opening = 0.0;

void fragment() {
	vec4 modulation = COLOR;
	vec2 p = UV * 2.0 - 1.0;
	vec3 crest = texture(aura_texture, UV).rgb;
	float elapsed = 1.0 - opening;
	float aperture = mix(0.14, 1.02, smoothstep(0.0, 0.88, elapsed));
	float reveal = 1.0 - smoothstep(aperture - 0.06, aperture + 0.08, abs(p.y));
	float scan = fract(TIME * pulse_speed * 0.66) * 3.0 - 1.5;
	float glint = 1.0 - smoothstep(0.035, 0.28, abs(p.x - scan + p.y * 0.18));
	float ignition = sin(elapsed * PI) * opening;
	float ink = crest.r * (0.57 + glint * 0.34 + ignition * 0.36);
	float feather = crest.b * (0.57 + selected * 0.20);
	float dusk = crest.g * (0.31 + selected * 0.13);
	float opacity = (ink + feather + dusk) * reveal * glow_strength;
	vec3 aura = mix(rarity_color.rgb, highlight_color.rgb, clamp(crest.r * 0.60 + feather + glint * crest.r * 0.25, 0.0, 1.0));
	COLOR = vec4(aura * modulation.rgb, clamp(opacity, 0.0, 1.0) * modulation.a);
}
