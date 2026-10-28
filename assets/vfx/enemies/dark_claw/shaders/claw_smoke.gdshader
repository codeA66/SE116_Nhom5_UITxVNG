shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
#include "res://assets/vfx/enemies/dark_claw/shaders/claw_common.gdshaderinc"

// 0 = ragged body behind each cut; 1 = drifting cloud; 2 = torn ink fragment.
uniform int kind = 0;
uniform float cut_index = 0.0;
varying vec4 instance_data;
varying float particle_alpha;

void vertex() {
	instance_data = INSTANCE_CUSTOM;
	particle_alpha = 1.0;
	float t = claw_time();
	if (kind > 0) {
		vec4 c = INSTANCE_CUSTOM;
		float birth = c.b * 0.19;
		float p = max(t - birth, 0.0);
		particle_alpha = smoothstep(0.0, 0.08, p) * (1.0 - smoothstep(0.48, 0.98, t)) * step(birth, t);
		vec2 q = VERTEX.xy;
		float grow = 0.45 + p * 1.3;
		q = spin2(q * grow, c.r * 6.28318 + p * (c.g - 0.5));
		q += vec2(sin(c.r * 19.0 + p * 4.0), cos(c.g * 17.0 + p * 3.0)) * p * 0.45;
		q.y += p * 0.4;
		VERTEX.xy = q;
	}
}

void fragment() {
	float t = claw_time();
	float alpha = 0.0;
	float rim = 0.0;
	if (kind == 0) {
		float u = UV.x;
		float v = UV.y * 2.0 - 1.0;
		float n = fbm(vec2(u * 31.0 + shape_seed + cut_index * 8.0, v * 5.0 + t * 1.8));
		float warp = sin(u * 27.0 + n * 7.0 + t * 3.0) * 0.16;
		float ragged = 0.18 + n * 0.7;
		float body = 1.0 - smoothstep(ragged * 0.7, ragged, abs(v + warp));
		float shards = smoothstep(0.46, 0.62, n) * (1.0 - smoothstep(0.6, 1.0, abs(v)));
		float head = clamp((t - 0.10) / 0.13, 0.0, 1.0);
		float reveal = 1.0 - smoothstep(head - 0.03, head + 0.03, 1.0 - u);
		alpha = max(body, shards * 0.8) * pow(max(sin(u * 3.14159), 0.0), 0.4) * reveal;
		alpha *= smoothstep(0.07, 0.15, t) * (1.0 - smoothstep(0.52, 0.98, t));
		rim = smoothstep(0.45, 0.75, n) * 0.7;
	} else {
		vec2 q = UV * 2.0 - 1.0;
		float seed = shape_seed + instance_data.r * 65.0;
		float n = fbm(q * 3.6 + seed + vec2(t * 0.55, -t * 0.7));
		if (kind == 2) {
			float edge = abs(q.x) * 0.7 + abs(q.y) * 0.9;
			alpha = (1.0 - smoothstep(0.55, 0.7, edge + n * 0.22)) * particle_alpha;
		} else {
			float radius = length(q + (n - 0.5) * 0.35);
			alpha = smoothstep(0.29, 0.64, n) * (1.0 - smoothstep(0.3, 1.02, radius)) * particle_alpha;
		}
		rim = smoothstep(0.58, 0.8, n);
	}
	ALBEDO = mix(vec3(0.0018, 0.001, 0.002), vec3(0.065, 0.002, 0.008), rim * 0.65);
	ALBEDO = palette_color(ALBEDO);
	ALPHA = alpha * 0.94;
}
