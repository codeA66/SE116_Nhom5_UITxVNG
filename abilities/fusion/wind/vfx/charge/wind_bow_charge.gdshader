shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 wind_color : source_color;
uniform vec4 edge_color : source_color;
uniform sampler2D streak_texture : filter_linear, repeat_disable;
uniform float phase = 0.0;
uniform float opacity = 0.0;
uniform float streak_length = 1.0;
uniform float orbit_radius = 0.15;
uniform float thickness = 0.1;
uniform float turns = 0.75;
uniform float count = 3.0;
uniform float charge = 0.0;
uniform float ready_pulse = 0.0;
uniform float ready_expansion = 0.25;
uniform float brightness_min = 0.65;
uniform float brightness_max = 1.0;
uniform float warm_scale = 1.0;
uniform float taper_power = 0.55;
uniform float tip_fade_fraction = 0.12;
uniform float edge_feather = 0.30;
uniform float texture_influence = 0.20;
uniform vec2 texture_uv_y = vec2(0.40, 0.61);
void vertex() {
	float u = UV.x;
	float strand = UV2.x;
	float angle = phase + strand / count * 6.283185 + u * turns * 6.283185;
	float taper = pow(max(sin(u * 3.141593), 0.0), taper_power);
	float radius = orbit_radius * (1.0 + ready_pulse * ready_expansion);
	radius += (UV.y - 0.5) * thickness * taper;
	VERTEX = vec3(cos(angle) * radius, sin(angle) * radius, -u * streak_length) * warm_scale;
}
void fragment() {
	float taper = smoothstep(0.0, tip_fade_fraction, UV.x) * (1.0 - smoothstep(1.0 - tip_fade_fraction, 1.0, UV.x));
	float cross_mask = 1.0 - smoothstep(0.5 - edge_feather, 0.5, abs(UV.y - 0.5));
	float tex = texture(streak_texture, vec2(UV.x, mix(texture_uv_y.x, texture_uv_y.y, UV.y))).r;
	ALBEDO = mix(edge_color.rgb, wind_color.rgb, cross_mask);
	ALBEDO *= mix(brightness_min, brightness_max, charge) + ready_pulse * ready_expansion;
	ALPHA = opacity * taper * cross_mask * mix(1.0 - texture_influence, 1.0, tex) * wind_color.a;
}
