shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://assets/vfx/shared/charms/song_tram/snap/shaders/slash_snap_shape.gdshaderinc"

uniform vec4 halo_color : source_color = vec4(0.055, 0.62, 0.86, 1.0);
uniform float halo_width : hint_range(0.04, 0.42) = 0.36;
uniform float halo_strength : hint_range(0.0, 2.0) = 0.38;

void fragment() {
	float t = returning ? 1.0 - UV.x : UV.x;
	float r = mix(radial_limits.x, radial_limits.y, UV.y);
	float belly = snap_belly(t);
	float rim = snap_contour(t, belly);
	float spread = (0.43 + 0.57 * belly) * halo_width;
	float band = 1.0 - smoothstep(0.0, spread, abs(r - rim + body_width * belly * 0.16));
	float ends = smoothstep(0.02, 0.23, t) * (1.0 - smoothstep(0.78, 1.0, t));
	float breath = 1.0 - smoothstep(0.05, 0.83, breakup);
	ALBEDO = halo_color.rgb;
	ALPHA = band * band * ends * (0.35 + 0.65 * belly) * breath * halo_strength * visibility_weight;
}
