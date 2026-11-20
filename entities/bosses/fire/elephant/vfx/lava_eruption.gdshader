shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform int layer = 0;
uniform float age = 0.0;
varying vec4 rock_seed;

#include "res://entities/bosses/fire/elephant/vfx/materials/lava_basalt.gdshaderinc"

void vertex() {
	rock_seed = INSTANCE_CUSTOM;
	if (layer == 2) {
		float t = max(age - 0.055 * rock_seed.b, 0.0);
		float lift = max(0.0, (2.7 + rock_seed.g * 3.5) * t - 6.6 * t * t);
		float direction = rock_seed.r * 6.283185;
		vec3 offset = vec3(cos(direction) * t * 0.66, lift - 0.22, sin(direction) * t * 0.66);
		MODELVIEW_MATRIX[3] += VIEW_MATRIX * vec4(offset, 0.0);
	} else if (layer == 1) {
		VERTEX.y *= 0.45 + 0.55 * sin(clamp(age * 2.7, 0.0, 1.0) * 3.14159);
	}
}

void fragment() {
	vec3 coal = vec3(0.11, 0.071, 0.056);
	vec3 scarlet = vec3(0.95, 0.065, 0.022);
	vec3 ember = vec3(1.0, 0.42, 0.09);
	float fade = 1.0 - smoothstep(0.53, 1.16, age);
	if (layer == 0) {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		float clay = basalt_noise(p * 23.0);
		float front = min(age * 5.4 + 0.075, 1.11);
		float reach = 1.0 - smoothstep(front - 0.09, front + 0.025, r + (clay - 0.5) * 0.06);
		float rim = 1.0 - smoothstep(0.87, 1.01, r + (clay - 0.5) * 0.10);
		float flash = (1.0 - smoothstep(0.012, 0.054, abs(r - front))) * (1.0 - smoothstep(0.12, 0.33, age));
		vec4 ground = basalt_ground(p, 0.99 - 0.54 * age, flash, 0.0, 0.0);
		ALBEDO = ground.rgb;
		ALPHA = reach * rim * fade * (0.70 + ground.a * 0.28);
	} else if (layer == 1) {
		float across = UV.x * 6.283185;
		float h = 1.0 - UV.y;
		float spray = basalt_noise(vec2(across * 8.8, h * 6.5 - age * 13.0));
		float pocket = 0.43 + 0.36 * sin(across * 19.0 + sin(across * 8.0) * 1.8);
		float top = pocket * (0.52 + 0.48 * basalt_noise(vec2(across * 9.0, age * 6.0)));
		float tongue = 1.0 - smoothstep(top - 0.025, top + 0.035, h);
		float broken = smoothstep(0.30, 0.65, spray + 0.17 * (1.0 - h));
		ALBEDO = mix(scarlet, ember, (1.0 - h) * spray);
		ALPHA = tongue * broken * smoothstep(0.0, 0.13, h) * (1.0 - smoothstep(0.10, 0.48, age)) * 0.82;
	} else {
		float grain = basalt_noise(UV * 26.0 + rock_seed.gb * 13.0);
		float fault = sin(UV.x * 22.0 + UV.y * 10.2 + rock_seed.b * 4.0 + grain * 1.24);
		float seam = (1.0 - smoothstep(0.030, 0.114, abs(fault))) * (0.50 + grain * 0.50);
		float shade = 0.42 + 0.48 * abs(dot(normalize(NORMAL), normalize(vec3(-0.4, 0.62, 0.70)))) + 0.13 * grain;
		vec3 basalt = mix(coal, vec3(0.31, 0.245, 0.183), rock_seed.g) * shade;
		ALBEDO = mix(basalt, mix(scarlet, ember, seam), seam * (0.95 - 0.56 * age));
		ALPHA = smoothstep(0.0, 0.065, age) * (1.0 - smoothstep(0.56, 0.94, age));
	}
}
