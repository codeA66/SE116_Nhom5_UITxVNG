shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://assets/vfx/shared/charms/song_tram/snap/shaders/slash_snap_shape.gdshaderinc"

uniform vec4 core_color : source_color = vec4(0.98, 1.0, 1.0, 1.0);
uniform vec4 inner_color : source_color = vec4(0.49, 0.73, 0.94, 1.0);
uniform vec4 rim_color : source_color = vec4(0.10, 0.82, 0.94, 1.0);
uniform float core_fraction : hint_range(0.1, 0.9) = 0.65;

void fragment() {
	vec4 shape = snap_shape(UV);
	float body_mix = shape.x / max(max(shape.x, shape.y), 0.0001);
	float inner_shade = (1.0 - smoothstep(0.01, 0.32, shape.z)) * 0.89;
	float rim = smoothstep(core_fraction + shape.w * 0.12, 1.0, shape.z);
	vec3 hue = mix(mix(core_color.rgb, inner_color.rgb, max(inner_shade, shape.w * 0.40)), rim_color.rgb, rim * 0.67);
	ALBEDO = mix(mix(rim_color.rgb, core_color.rgb, 0.76), hue, body_mix);
	ALPHA = max(shape.x, shape.y) * visibility_weight;
}
