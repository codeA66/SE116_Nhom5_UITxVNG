shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
#include "res://assets/vfx/enemies/dark_claw/shaders/claw_common.gdshaderinc"

uniform bool soft_layer = false;
uniform float cut_index = 0.0;
uniform vec4 hot_color : source_color = vec4(1.0, 0.62, 0.53, 1.0);

void fragment() {
	float t = claw_time();
	float u = UV.x;
	float v = UV.y * 2.0 - 1.0;
	float seed = shape_seed + cut_index * 13.7;
	// UV.x runs bottom-to-top; paint from the upper tip down the curved path.
	float paint_u = 1.0 - u;
	float head = clamp((t - 0.115 - cut_index * 0.008) / 0.155, 0.0, 1.0);
	float reveal = (1.0 - smoothstep(head - 0.006, head + 0.008, paint_u)) * step(0.002, head);
	// The moving head is tapered like a brush tip; the deposited stroke stays put.
	float brush_tip = mix(smoothstep(0.0, 0.045, head - paint_u), 1.0, smoothstep(0.97, 1.0, head));
	float tail = 1.0 - smoothstep(0.29, 0.94, t);
	float roughness = fbm(vec2(u * 47.0 + seed, v * 3.0 - t * 2.0));
	float spine = (noise21(vec2(u * 65.0 + seed, 4.5)) - 0.5) * 0.16;
	float d = abs(v - spine);
	float taper = pow(max(sin(u * 3.14159265), 0.0), 0.45);
	float dissolving = smoothstep(0.40, 0.98, t);
	float erosion = smoothstep(dissolving - 0.04, dissolving + 0.13, roughness * 0.85 + 0.27);
	float aa = max(fwidth(v), 0.006);
	if (soft_layer) {
		float halo = pow(max(1.0 - d, 0.0), 2.6) * (0.55 + roughness * 0.7);
		ALBEDO = edge_color.rgb * intensity * 0.9;
		ALPHA = halo * taper * reveal * brush_tip * tail * erosion * 0.40;
	} else {
		float blade_width = (0.12 + roughness * 0.95) * brush_tip;
		float blade = 1.0 - smoothstep(blade_width - aa, blade_width + aa, d);
		float fibers = fbm(vec2(u * 88.0 + seed, v * 11.0 + seed));
		float texture_gain = 0.32 + 0.68 * smoothstep(0.22, 0.62, fibers);
		float grain = 0.20 + 0.80 * smoothstep(0.27, 0.62, fbm(vec2(u * 32.0, seed + 10.0)));
		float hot = (1.0 - smoothstep(0.012, 0.055 + roughness * 0.035, d)) * grain * brush_tip;
		float veins = pow(max(1.0 - abs(v - sin(u * 52.0 + seed) * 0.3) * 13.0, 0.0), 2.0) * 0.32;
		float flash = 1.0 + 0.35 * (1.0 - smoothstep(0.20, 0.32, t));
		ALBEDO = mix(edge_color.rgb * 1.05 * texture_gain, hot_color.rgb * 2.2, clamp(hot, 0.0, 1.0)) * intensity * flash;
		ALPHA = max(blade, veins) * taper * reveal * tail * erosion;
	}
	ALBEDO = palette_color(ALBEDO);
}
