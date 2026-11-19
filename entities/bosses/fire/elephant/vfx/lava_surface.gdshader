shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://entities/bosses/fire/elephant/vfx/materials/lava_basalt.gdshaderinc"

// 0: vũng, 1: sóng, 2: giọt, 3: lớp dung nham trên vòi.
uniform int style = 0;
uniform vec4 crust : source_color = vec4(0.32, 0.125, 0.085, 1.0);
uniform vec4 melt : source_color = vec4(1.0, 0.24, 0.018, 1.0);
uniform float wave_radius = 1.0;
uniform float wave_width = 1.28;
uniform float wave_half_angle = 0.80285;
uniform float wave_age = 0.0;
uniform float wave_fade = 1.0;
uniform vec2 arena_center;
uniform vec2 arena_extent = vec2(18.0, 16.0);
varying vec2 wave_metres;
varying vec2 wave_world;

vec2 jitter(vec2 cell) {
	vec2 seed = fract(cell * vec2(0.1031, 0.11369));
	seed += dot(seed, seed.yx + 19.19);
	return fract(vec2(seed.x * seed.y, seed.x * seed.x)) * 0.86 + 0.07;
}

vec3 plates(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 closest = vec2(8.0);
	float shade = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 seed = jitter(cell + offset);
			vec2 direction = offset + seed - local;
			float distance_sq = dot(direction, direction);
			if (distance_sq < closest.x) {
				closest = vec2(distance_sq, closest.x);
				shade = seed.x;
			} else {
				closest.y = min(closest.y, distance_sq);
			}
		}
	}
	return vec3(sqrt(closest.y) - sqrt(closest.x), shade, closest.x);
}

void vertex() {
	if (style == 1) {
		float angle = (2.0 * UV.x - 1.0) * wave_half_angle;
		float along = angle * wave_radius;
		float taper = pow(max(0.0, sin(3.14159 * UV.x)), 0.62);
		float depth = min(wave_width, wave_radius * 0.44) * taper;
		float travelled = UV.y * depth;
		float ripples = sin(along * 5.1 - wave_age * 8.0) * 0.055
			+ sin(along * 13.7 + wave_age * 14.0) * 0.026;
		float edge = wave_radius - travelled + ripples * taper;
		float curl = (1.0 - taper) * travelled * 0.17;
		float crest = sin(3.14159 * min(UV.y, 1.0)) * exp(-UV.y * 1.95);
		float height = crest * (0.49 + ripples * 2.45) * taper;
		VERTEX = vec3(sin(angle + sign(angle) * curl) * edge, height, cos(angle + sign(angle) * curl) * edge);
		wave_metres = vec2(along, travelled);
		wave_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	}
}

void fragment() {
	if (style == 0) {
		vec2 p = (UV - 0.5) * 2.0;
		float smoulder = 0.94 + 0.085 * sin(TIME * 1.6 + length(p) * 9.0);
		float edge = smoothstep(0.69, 1.02, length(p));
		ALBEDO = basalt_ground(p * 0.43, smoulder, 0.0, 0.24, 0.86).rgb * mix(1.0, 0.79, edge);
	} else {
		vec2 tile_count = vec2(5.4);
		if (style == 2) {
			tile_count = vec2(4.0, 2.6);
		} else if (style == 3) {
			tile_count = vec2(4.0, 2.5);
		}
		vec2 sample_point = UV * tile_count;
		if (style == 1) {
			float shear = sin(wave_metres.x * 4.2 - wave_age * 6.0) * 0.16;
			sample_point = (wave_metres + vec2(wave_age * 0.58 + shear, wave_age * 1.7)) * vec2(3.1, 3.9);
		}
		vec3 plate = plates(sample_point);
		float pulse = 0.93 + 0.07 * sin(TIME * 3.0 + plate.y * 15.0);
		float fissure = 1.0 - smoothstep(0.014, 0.075, plate.x);
		float heat = 1.0 - smoothstep(0.03, 0.26, plate.x);
		vec3 stone = crust.rgb * (0.63 + plate.y * 0.76 + 0.15 * smoothstep(0.1, 0.4, plate.z));
		vec3 color = mix(stone, melt.rgb * pulse, heat * 0.82);
		color = mix(color, vec3(1.0, 0.69, 0.13), fissure * pulse * 0.94);
		if (style == 1) {
			float tips = sin(3.14159 * UV.x);
			float streak = sin(wave_metres.x * 28.0 + sin(wave_metres.x * 19.0 - wave_age * 9.0) * 2.2) * 0.5 + 0.5;
			float ragged_end = mix(0.76, 1.21, streak * streak) * (0.90 + 0.1 * tips);
			float breakup = 0.77 + 0.23 * plate.y;
			vec2 wall = arena_extent - abs(wave_world - arena_center);
			float clearance = min(wall.x, wall.y);
			if (clearance < 0.18 + 0.16 * plate.y) {
				discard;
			}
			if (UV.y > ragged_end * smoothstep(0.0, 0.31, wave_fade) || wave_fade < (1.0 - breakup) * (0.48 + UV.y * 0.52)) {
				discard;
			}
			float lip = 1.0 - smoothstep(0.014, 0.09 + 0.042 * streak, wave_metres.y);
			float hot_shear = pow(max(0.0, sin(wave_metres.y * 33.0 + wave_metres.x * 3.2 + wave_age * 15.0)), 10.0);
			color = mix(color, melt.rgb, lip * 0.82 + hot_shear * 0.10);
			color = mix(color, vec3(1.0, 0.79, 0.28), pow(lip, 1.45) * (0.68 + 0.27 * streak));
			color *= mix(1.0, 0.48, smoothstep(0.68, 1.2, UV.y));
			color *= mix(vec3(0.55, 0.34, 0.22), vec3(1.0), smoothstep(0.19, 0.60, clearance));
		} else {
			float edge = pow(1.0 - abs(NORMAL.z), 2.0);
			color = mix(color, melt.rgb, edge * 0.65 + 0.18);
			color = mix(color, vec3(1.0, 0.79, 0.24), edge * 0.48);
		}
		ALBEDO = color;
	}
}
