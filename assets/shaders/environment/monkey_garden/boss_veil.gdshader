shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 darkness : source_color = vec4(0.025, 0.032, 0.038, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float drift = sin(UV.x * 15.0 + TIME * 0.13) * sin(UV.y * 11.0 - TIME * 0.09);
	ALBEDO = darkness.rgb * (0.85 + drift * 0.15);
	ALPHA = opacity;
}
