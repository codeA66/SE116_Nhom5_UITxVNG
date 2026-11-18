shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 wind_color : source_color = vec4(0.72, 0.9, 1.0, 0.65);
uniform float effect_time = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform bool ring = false;
void fragment() {
	float edge = pow(max(0.0, 1.0 - abs(UV.y * 2.0 - 1.0)), 1.6);
	float taper = smoothstep(0.0, 0.13, UV.x) * (1.0 - smoothstep(0.68, 1.0, UV.x));
	float flow = fract(UV.x * 1.35 - effect_time * 3.2 + phase);
	float streak = smoothstep(0.0, 0.22, flow) * (1.0 - smoothstep(0.58, 1.0, flow));
	float mask = ring ? edge : edge * taper * (0.22 + 0.78 * streak);
	ALBEDO = wind_color.rgb;
	ALPHA = wind_color.a * strength * mask;
}
