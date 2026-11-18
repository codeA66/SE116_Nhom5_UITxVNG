shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

#include "../vfx_common.gdshaderinc"

uniform sampler2D shape_mask : hint_default_white, filter_linear, repeat_disable;
uniform int reveal_mode : hint_enum("Radial fill", "Angular wipe", "Pulse", "Mask only") = 0;
uniform float track_opacity : hint_range(0.0, 1.0) = 0.24;
uniform float field_opacity : hint_range(0.0, 1.0) = 0.18;
uniform float field_radius : hint_range(0.05, 1.0) = 0.76;
uniform float softness : hint_range(0.001, 0.2) = 0.025;
uniform float pulse_speed : hint_range(0.0, 20.0) = 4.0;
uniform float intensity : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float radius = length(point);
	float progress = clamp(vfx_progress, 0.0, 1.0);
	float phase = 1.0;
	float field = 0.0;
	float shape = texture(shape_mask, UV).r;
	if (reveal_mode == 0 || reveal_mode == 1) {
		float distance_to_start = radius / max(field_radius, 0.001);
		if (reveal_mode == 1) {
			distance_to_start = fract(atan(point.x, -point.y + 0.00001) / TAU + 1.0);
		}
		float edge = max(softness, min(fwidth(distance_to_start), 0.08));
		float revealed = progress <= 0.0 ? 0.0 :
			1.0 - smoothstep(progress, progress + edge, distance_to_start);
		float circle = 1.0 - smoothstep(field_radius, field_radius + softness, radius);
		field = circle * revealed * field_opacity;
		phase = reveal_mode == 0 ? mix(track_opacity, 1.0, progress) :
			mix(track_opacity, 1.0, revealed);
	} else if (reveal_mode == 2) {
		phase = mix(track_opacity, 1.0, 0.5 + 0.5 * sin(TIME * TAU * pulse_speed)) * progress;
	}
	vec4 palette = vfx_sample_palette(mix(0.34, 0.86, shape * phase));
	ALBEDO = palette.rgb * intensity;
	ALPHA = clamp(max(shape * phase, field) * palette.a * vfx_opacity, 0.0, 1.0);
}
