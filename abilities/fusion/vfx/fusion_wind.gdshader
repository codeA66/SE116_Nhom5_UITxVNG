shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform sampler2D streak_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D wisp_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform vec2 streak_uv_y = vec2(0.40, 0.61);
uniform vec2 wisp_uv_y = vec2(0.36, 0.66);
uniform vec4 core_color : source_color = vec4(0.96, 0.98, 0.93, 1.0);
uniform vec4 body_color : source_color = vec4(0.42, 0.60, 0.65, 1.0);
uniform vec4 edge_color : source_color = vec4(0.12, 0.22, 0.27, 1.0);
uniform float opacity = 0.96;
uniform float emission_strength = 0.08;
uniform float appear_time = 0.035;
uniform float rim_width = 0.035;
uniform float rim_opacity = 0.55;
// 0 lưỡi kiếm, 1 đuôi kiếm, 2 gió sát sàn, 3 thân phễu, 4 nét sắc,
// 5 hạt CPU, 7 chớp va chạm, 8 khí nén ở tâm.
uniform int effect_mode = 0;
uniform float age = 0.0;
uniform float dissolve = 0.0;
uniform float layer_opacity = 1.0;
uniform float seed = 0.0;
uniform float radius = 2.5;
uniform float inward_speed = 1.65;
uniform float spin_speed = 8.0;
uniform float arc_length = 2.5;
uniform float ribbon_width = 0.40;
uniform float body_width = 0.50;
uniform float ground_offset = 0.08;
uniform float lift = 1.15;
uniform float stop_age = -1.0;
uniform float close_time = 0.22;
uniform float flash_time = 0.085;
uniform float flash_at = 0.0;
uniform float launch_overshoot = 0.18;
uniform float launch_settle_time = 0.07;
uniform float sweep_time = 0.045;
uniform float swing_turn_degrees = 25.0;
uniform float travel_duration = 0.33;
uniform float impact_pull_time = 0.15;

varying float visibility;
varying vec4 particle_color;

void vertex() {
	particle_color = vec4(1.0);
	float closing = stop_age < 0.0 ? 0.0 : clamp((age - stop_age) / max(close_time, 0.001), 0.0, 1.0);
	float collapse = 1.0 - closing * closing * 0.96;
	visibility = smoothstep(0.0, max(appear_time, 0.001), age) * (1.0 - smoothstep(0.65, 1.0, closing));
	if (effect_mode == 0 || effect_mode == 1 || effect_mode == 9 || effect_mode == 10) {
		float pop = smoothstep(0.0, appear_time, age);
		float settle = 1.0 - smoothstep(appear_time, launch_settle_time, age);
		VERTEX.x *= mix(0.72, 1.0 + launch_overshoot * settle, pop);
		VERTEX.z *= 1.0 + launch_overshoot * settle;
		float swing = radians(swing_turn_degrees) * (smoothstep(0.0, max(travel_duration * 0.7, 0.001), age) - 0.5);
		VERTEX.xz = mat2(vec2(cos(swing), sin(swing)), vec2(-sin(swing), cos(swing))) * VERTEX.xz;
	}
	if (effect_mode >= 2 && effect_mode <= 4) {
		float phase = fract(age * inward_speed + INSTANCE_CUSTOM.r);
		float taper = pow(max(sin(UV.x * 3.141593), 0.0), 0.7);
		float angle = INSTANCE_CUSTOM.g * 6.283185 + age * spin_speed + spin_speed * 0.04 * (1.0 - exp(-age * 20.0));
		float radial;
		float elevation;
		float width;
		if (effect_mode == 2) {
			angle += UV.x * arc_length;
			radial = radius * (0.06 + (1.0 - phase) * 0.70 + UV.x * 0.18);
			width = ribbon_width * mix(0.65, 1.2, INSTANCE_CUSTOM.b);
			radial += (UV.y - 0.5) * width * taper;
			elevation = ground_offset + INSTANCE_CUSTOM.b * 0.06;
			visibility *= smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.78, 1.0, phase));
		} else if (effect_mode == 3) {
			float h = UV.x;
			angle += h * 5.4 + INSTANCE_CUSTOM.r;
			radial = radius * (0.09 + pow(1.0 - h, 1.1) * 0.73);
			radial *= 0.96 + 0.04 * sin(angle * 2.0 + age * 5.0);
			elevation = ground_offset + h * lift * mix(0.85, 1.1, INSTANCE_CUSTOM.b);
			width = body_width * taper;
			radial += (UV.y - 0.5) * width * 0.5;
			elevation += (UV.y - 0.5) * width;
		} else {
			float h = clamp(phase * 0.73 + UV.x * 0.25, 0.0, 1.0);
			angle += UV.x * arc_length;
			radial = radius * (0.10 + (1.0 - h) * 0.65);
			width = ribbon_width * 0.85 * taper;
			radial += (UV.y - 0.5) * width * 0.5;
			elevation = ground_offset + h * lift + (UV.y - 0.5) * width;
			visibility *= smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.82, 1.0, phase));
		}
		VERTEX = vec3(cos(angle) * radial * collapse, elevation * collapse, sin(angle) * radial * collapse);
	}
	if (effect_mode == 5) {
		vec3 center = MODEL_MATRIX[3].xyz;
		float size = max(length(MODEL_MATRIX[1].xyz), 0.00001);
		vec3 axis = MODEL_MATRIX[1].xyz / size;
		vec3 view_direction = normalize(INV_VIEW_MATRIX[3].xyz - center);
		vec3 side = cross(axis, view_direction);
		side /= max(length(side), 0.00001);
		vec3 world = center + axis * VERTEX.y * size + side * VERTEX.x * size;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
		particle_color = COLOR;
		visibility = 1.0;
	}
	if (effect_mode == 7) {
		float flash_age = max(age - flash_at, 0.0);
		visibility = (1.0 - smoothstep(0.0, flash_time, flash_age)) * step(flash_at, age);
		VERTEX *= mix(0.5, 1.3, clamp(flash_age / max(flash_time, 0.001), 0.0, 1.0));
	}
	if (effect_mode == 8) { VERTEX *= collapse; }
	if (effect_mode == 14) { visibility *= 1.0 - smoothstep(impact_pull_time * 0.65, impact_pull_time, age); }
	// Shader có nhánh billboard tự ghi POSITION nên các lớp mesh cũng phải xuất vị trí.
	if (effect_mode != 5) { POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0); }
}

void fragment() {
	vec2 uv = vec2(UV.x, mix(streak_uv_y.x, streak_uv_y.y, UV.y));
	if (effect_mode == 5) { uv = vec2(1.0 - UV.y, mix(streak_uv_y.x, streak_uv_y.y, UV.x)); }
	vec4 stroke = texture(streak_texture, uv);
	float noise = texture(noise_texture, UV * vec2(1.9, 1.1) + vec2(-age * 1.1 + seed, age * 0.23)).r;
	float border = smoothstep(0.0, 0.045, UV.x) * (1.0 - smoothstep(0.955, 1.0, UV.x));
	border *= smoothstep(0.0, 0.035, UV.y) * (1.0 - smoothstep(0.965, 1.0, UV.y));
	float alpha = stroke.a;
	vec3 color = mix(body_color.rgb, core_color.rgb, smoothstep(0.2, 0.7, stroke.a));
	if (effect_mode == 0 || effect_mode == 9 || effect_mode == 10) {
		// Một khối chính: mép trước sắc, bụng khí trong mờ, phần sau bị xé dần.
		float front = smoothstep(0.42, 0.63, UV.y);
		float blade = smoothstep(0.03, 0.065, UV.y) * (1.0 - smoothstep(0.965, 0.99, UV.y));
		float tear = smoothstep(0.10 + dissolve * 1.05, 0.22 + dissolve * 1.05, noise + UV.y * 0.45);
		alpha = blade * stroke.a * tear;
		// Những rãnh cong lớn chia thân thành vệt quét, giữ mép trước liền và sắc.
		float cuts = 0.0;
		for (int band = 0; band < 3; band++) {
			float line = 0.16 + float(band) * 0.14 + sin(UV.x * 8.0 + float(band) * 1.7 - age * 6.0) * 0.018;
			cuts = max(cuts, 1.0 - smoothstep(0.008, 0.025, abs(UV.y - line)));
		}
		alpha *= 1.0 - cuts * (1.0 - smoothstep(0.55, 0.78, UV.x)) * 0.45;
		color = mix(body_color.rgb, core_color.rgb, smoothstep(0.25, 0.90, stroke.a) * (0.45 + front * 0.55));
		if (effect_mode == 9) { color = mix(edge_color.rgb, body_color.rgb, 0.20); }
		if (effect_mode == 10) {
			alpha = smoothstep(0.0, 0.5, stroke.a) * 0.6;
			color = mix(body_color.rgb, core_color.rgb, 0.15);
		}
		float rim = smoothstep(0.87, 0.93, UV.y);
		color = mix(color, edge_color.rgb, rim * rim_opacity);
	} else if (effect_mode == 14) {
		float r = length(UV * 2.0 - 1.0);
		float ring = 1.0 - pow(clamp(age / max(impact_pull_time, 0.001), 0.0, 1.0), 0.7);
		float separation = abs(r - ring);
		alpha = 1.0 - smoothstep(0.05, 0.11, separation);
		color = mix(body_color.rgb, core_color.rgb, 1.0 - smoothstep(0.02, 0.07, separation));
	} else if (effect_mode == 11 || effect_mode == 13) {
		float width = max(pow(UV.y, 0.55) * pow(1.0 - UV.y, 1.8) * 3.0, 0.001);
		float edge_distance = abs(UV.x * 2.0 - 1.0) / width;
		alpha = 1.0 - smoothstep(0.75, 1.0, edge_distance);
		float core = 1.0 - smoothstep(0.15, 0.65, edge_distance);
		color = mix(body_color.rgb, core_color.rgb, core);
		if (effect_mode == 13) {
			alpha = (1.0 - smoothstep(0.0, 1.2, edge_distance)) * 0.3;
			color = body_color.rgb;
		}
	} else if (effect_mode == 12) {
		float tail = max(pow(1.0 - UV.y, 0.7), 0.001);
		float bend = sin(UV.y * 11.0 - age * 28.0) * UV.y * 0.20;
		float x = (UV.x * 2.0 - 1.0 - bend) / tail;
		float envelope = 1.0 - smoothstep(0.70, 1.0, abs(x));
		float lines = max(1.0 - smoothstep(0.06, 0.19, abs(x - 0.30)), 1.0 - smoothstep(0.06, 0.19, abs(x + 0.30)));
		alpha = envelope * tail * mix(0.45, 0.95, lines);
		color = mix(body_color.rgb, core_color.rgb, lines * 0.8);
	} else if (effect_mode == 3) {
		vec2 wisp_uv = vec2(UV.x, mix(wisp_uv_y.x, wisp_uv_y.y, UV.y));
		float fibers = texture(wisp_texture, wisp_uv).a;
		float ribbon = smoothstep(0.04, 0.10, UV.y) * (1.0 - smoothstep(0.90, 0.96, UV.y));
		alpha = ribbon * smoothstep(0.24, 0.34, noise) * mix(0.84, 1.0, fibers);
		color = mix(body_color.rgb, core_color.rgb, smoothstep(0.58, 0.68, UV.y) * 0.70);
	} else if (effect_mode == 1) {
		vec2 wisp_uv = vec2(UV.x, mix(wisp_uv_y.x, wisp_uv_y.y, UV.y));
		alpha = texture(wisp_texture, wisp_uv).a;
		alpha *= smoothstep(0.23, 0.56, noise + sin(UV.x * 12.0 - age * 8.0) * 0.12);
		color = mix(body_color.rgb, core_color.rgb, alpha * 0.35);
	} else if (effect_mode == 7) {
		vec2 p = UV * 2.0 - 1.0;
		float star = pow(max(1.0 - abs(p.x), 0.0), 8.0) * pow(max(1.0 - abs(p.y), 0.0), 1.5);
		star += pow(max(1.0 - abs(p.y), 0.0), 8.0) * pow(max(1.0 - abs(p.x), 0.0), 1.5);
		alpha = clamp(star, 0.0, 1.0);
		color = core_color.rgb;
	} else if (effect_mode == 8) {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		float swirl = texture(noise_texture, vec2(atan(p.y, p.x) / 6.283185 - age, r * 1.5 - age)).r;
		alpha = (1.0 - smoothstep(0.1, 1.0, r)) * mix(0.2, 0.8, swirl);
		color = mix(edge_color.rgb, body_color.rgb, swirl);
	} else if (effect_mode != 5) {
		float rim = max(texture(streak_texture, uv + vec2(0.0, rim_width)).a, texture(streak_texture, uv - vec2(0.0, rim_width)).a) * rim_opacity;
		float coverage = alpha + rim * (1.0 - alpha);
		color = (color * alpha + edge_color.rgb * rim * (1.0 - alpha)) / max(coverage, 0.001);
		alpha = coverage;
	}
	float erode = smoothstep(dissolve * 1.2 - 0.18, dissolve * 1.2 + 0.10, noise + UV.y * 0.18);
	float end_fade = (effect_mode == 0 || effect_mode == 9) ? 1.0 - smoothstep(0.68, 1.0, dissolve) : 1.0 - dissolve;
	if (effect_mode == 0 || effect_mode == 9 || effect_mode == 1 || effect_mode == 10) {
		float sweep = clamp(age / max(sweep_time, 0.001), 0.0, 1.0) * 1.12;
		alpha *= smoothstep(UV.x - 0.06, UV.x + 0.06, sweep);
	}
	ALBEDO = color * particle_color.rgb;
	EMISSION = ALBEDO * emission_strength;
	ALPHA = clamp(alpha * opacity * layer_opacity * visibility * border * erode * end_fade * particle_color.a, 0.0, 1.0);
}
