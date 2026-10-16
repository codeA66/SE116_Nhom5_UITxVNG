shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://assets/shaders/wind_flow.gdshaderinc"
uniform sampler2D mask_texture : repeat_disable, filter_linear;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 0.5;
uniform float clock = 0.0;
uniform float breathing_speed = 3.0;
uniform float position_in_flow = 0.0;
uniform bool warning_only = false;
uniform float ring_thickness = 1.0;
uniform bool broken_ring = false;
void fragment() {
	vec2 sample_uv = UV;
	if (abs(ring_thickness - 1.0) > 0.001) {
		vec2 v = UV * 2.0 - 1.0;
		float r = length(v);
		float rr = 0.78 + (r - 0.78) / max(ring_thickness, 0.01);
		sample_uv = vec2(0.5) + v / max(r, 0.001) * rr * 0.5;
	}
	vec4 mask = texture(mask_texture, sample_uv);
	float breathing = 0.85 + 0.15 * sin(clock * breathing_speed);
	float broken = 1.0;
	if (broken_ring) {
		vec2 radial = UV * 2.0 - 1.0;
		float a = atan(radial.y, radial.x);
		broken = smoothstep(-0.4, 0.55, sin(a * 3.0 + clock * 0.5) + sin(a * 5.0 - clock * 0.3) * 0.35);
	}
	float field = warning_only ? 1.0 : wind_mask(position_in_flow);
	ALBEDO = tint.rgb;
	ALPHA = mask.a * COLOR.a * opacity * tint.a * breathing * field * broken;
}
