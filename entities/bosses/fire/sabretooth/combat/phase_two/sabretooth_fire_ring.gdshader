shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform bool shockwave = false;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
varying float flame;

void vertex() {
	flame = UV2.x;
}

void fragment() {
	float angle = UV.x * 6.283185;
	float radial = abs(UV.y - 0.5);
	float noise = sin(angle * 21.0 - TIME * 9.0 + sin(angle * 9.0 + TIME * 6.0) * 1.4);
	float edge = clamp(fwidth(radial), 0.01, 0.06);
	vec3 red = vec3(0.70, 0.017, 0.026);
	vec3 hot = vec3(1.0, 0.14, 0.045);
	vec3 amber = vec3(1.0, 0.48, 0.12);
	float alpha;
	vec3 fire;
	if (flame > 0.5) {
		float twist = sin(angle * 11.0 - TIME * 8.0 + UV.y * 4.0);
		float strand = sin(angle * 37.0 + twist * 1.5 - TIME * 15.0 - UV.y * 8.0);
		float tongue = 0.28 + 0.57 * pow(max(0.0, noise), 1.65) + strand * 0.14;
		float height = tongue * mix(0.70, 1.10, progress);
		alpha = (1.0 - smoothstep(height - 0.07, height + 0.04, UV.y)) * (1.0 - UV.y * 0.75);
		fire = mix(red, hot, smoothstep(0.1, 0.95, 1.0 - UV.y));
		fire = mix(fire, amber, max(0.0, strand) * pow(1.0 - UV.y, 2.6) * 0.55);
	} else {
		float core = 1.0 - smoothstep(0.023, 0.068 + edge, radial);
		float halo = (1.0 - smoothstep(0.018, 0.37, radial)) * 0.57;
		alpha = max(core, halo);
		fire = mix(vec3(0.37, 0.009, 0.028), red, alpha);
		fire = mix(fire, hot, core * (0.40 + 0.20 * noise));
		if (shockwave) {
			alpha *= 1.0 - smoothstep(0.06, 0.55, progress);
			fire = mix(hot, amber, core * 0.87);
		}
	}
	ALBEDO = fire;
	EMISSION = fire * (shockwave ? 0.75 : mix(0.52, 1.0, progress));
	ALPHA = alpha;
}
