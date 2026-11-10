shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D noise_texture : filter_linear, repeat_enable;
uniform sampler2D flame_map : source_color, filter_linear_mipmap, repeat_disable;
uniform float flow_speed = 1.8;
uniform float flow_curl = 0.06;
uniform vec4 core_color : source_color;
uniform vec4 hot_color : source_color;
uniform vec4 body_color : source_color;
uniform vec4 edge_color : source_color;
uniform float clock = 0.0;
uniform float progress = 0.0;
uniform float dissolve = 0.0;
uniform float opacity = 0.0;
uniform float reach = 1.65;
uniform float reach_ratio = 0.98;
uniform float inner_ratio = 0.2;
uniform float arc_radians = 3.0;
uniform float sweep_sign = 1.0;
uniform float height = 0.65;
uniform float tilt = 0.0;
uniform float depth = 0.1;
uniform float curl = 0.1;
uniform float curl_speed = 10.0;
uniform float curl_turns = 0.8;
uniform float secondary_width = 0.05;
uniform float leading_weight = 0.35;
uniform float maximum_body_fill = 0.60;
uniform float taper_power = 0.6;
uniform float strand_count = 3.0;
uniform float edge_width = 0.06;
uniform vec2 erode_scale = vec2(12.0, 4.0);
uniform float erode_sharpness = 0.018;
uniform float flash_duration = 0.035;
uniform float flash_size = 0.3;
uniform float dust_size = 0.05;
uniform float dust_drift = 0.15;
uniform float body_gain = 1.0;
uniform float heat_gain = 0.0;
uniform bool clip_box = false;
uniform vec3 box_center = vec3(0.0);
uniform vec3 box_size = vec3(1.0);
uniform float warm_scale = 1.0;
uniform float tongue_count = 7.0;
uniform float tongue_size = 0.15;
uniform float flame_lift = 0.0;
uniform float reveal_power = 3.0;
uniform bool finisher = false;
uniform int finisher_streak_count = 1;
uniform int visible_streak_count = 1;
uniform int finisher_ember_count = 3;
uniform float finisher_pitch = 0.8;
uniform float visual_scale = 1.64;
uniform float echo_scale = 1.12;
uniform float echo_height = 0.16;
uniform float echo_delay = 0.025;
uniform float sweep_duration = 0.065;
uniform float active_duration = 0.1;
uniform float hold_duration = 0.055;
uniform float release_duration = 0.22;
varying float kind;
varying float strand;
varying float stroke_visible;
void vertex() {
	kind = UV2.y;
	strand = UV2.x;
	stroke_visible = 1.0;
	if (kind < 0.5 && strand >= float(visible_streak_count)) stroke_visible = 0.0;
	if (!finisher && kind > 1.5) stroke_visible = 0.0;
	if (finisher && kind > 0.5 && kind < 1.5 && strand > strand_count + float(finisher_ember_count)) stroke_visible = 0.0;
	float u = UV.x;
	float side = UV.y;
	float angle = (u - 0.5) * arc_radians * sweep_sign;
	float outer = reach * reach_ratio;
	float taper = pow(max(sin(u * 3.141593), 0.0), taper_power);
	vec3 p;
	if (kind > 1.5) {
		float a = (min(progress * 1.2, 1.0) - 0.5) * arc_radians * sweep_sign;
		p = vec3(sin(a) * outer * 0.80, height, cos(a) * outer * 0.80);
		p += vec3((u - 0.5) * flash_size, (side - 0.5) * flash_size, 0.0);
	} else if (kind > 0.5) {
		float seed = fract(strand * 0.618034);
		float phase = clamp(seed + clock * dust_drift, 0.0, 1.0);
		float a = (phase - 0.5) * arc_radians * sweep_sign;
		float r = outer * mix(inner_ratio, 0.94, fract(strand * 0.381966));
		p = vec3(sin(a) * r, height + sin(clock * 8.0 + strand) * dust_size, cos(a) * r);
		p += vec3((u - 0.5) * dust_size, (side - 0.5) * dust_size, (side - 0.5) * dust_size);
	} else {
		// Cùng hình cung bản đầu: thường một cung, nhát cuối hai cung lớn nghiêng đối nhau.
		float echo = step(0.5, strand);
		float stroke_scale = outer * visual_scale * mix(1.0, echo_scale, echo);
		float envelope = pow(max(sin(u * 3.141593), 0.0), taper_power);
		float r = 1.0 - (1.0 - inner_ratio) * envelope * (1.0 - side) * min(body_gain, 1.0);
		float tongue = pow(max(sin(u * 6.283185 * tongue_count + sin(u * 11.0)), 0.0), 3.0);
		r += tongue * tongue_size * envelope * side;
		p = vec3(sin(angle) * r, (side - 0.5) * depth * envelope, cos(angle) * r) * stroke_scale;
		p.y += height + echo * echo_height;
		p.y += p.x * sin(tilt) * sweep_sign * mix(1.0, -1.0, echo);
		p.y += sin(u * 19.0 - clock * flow_speed * 8.0) * flow_curl * sin(side * 3.141593);
	}
	if (clip_box && !finisher) {
		vec3 half_size = box_size * 0.5;
		p = clamp(p, box_center - half_size, box_center + half_size);
	}
	float r = length(p.xz);
	if (kind > 0.5 && !finisher && r > outer) p.xz *= outer / max(r, 0.001);
	VERTEX = p * warm_scale;
}
void fragment() {
	if (stroke_visible < 0.5) discard;
	float aa = max(fwidth(UV.y), 0.001);
	float alpha;
	vec3 color;
	if (kind > 1.5) {
		vec2 q = abs(UV - vec2(0.5));
		float star = min(q.x + q.y * 3.0, q.y + q.x * 3.0);
		alpha = (1.0 - smoothstep(0.16, 0.20, star)) * (1.0 - step(flash_duration, clock));
		color = core_color.rgb;
	} else if (kind > 0.5) {
		vec2 q = abs(UV - vec2(0.5));
		alpha = 1.0 - smoothstep(0.42, 0.48, q.x * 0.8 + q.y);
		alpha *= 1.0 - step(fract(strand * 0.2718), dissolve);
		color = mix(body_color.rgb, hot_color.rgb, fract(strand * 0.7));
	} else {
		float stroke_progress = progress;
		float stroke_dissolve = dissolve;
		if (finisher) {
			float age = max(clock - step(0.5, strand) * echo_delay, 0.0);
			stroke_progress = clamp(age / max(sweep_duration, 0.001), 0.0, 1.0);
			stroke_dissolve = clamp((age - active_duration - hold_duration) / max(release_duration, 0.001), 0.0, 1.0);
		}
		float head = min((1.0 - pow(1.0 - stroke_progress, reveal_power)) * 1.05, 1.0);
		alpha = (1.0 - smoothstep(head - aa, head + aa, UV.x));
		alpha *= smoothstep(0.0, aa, UV.y) * (1.0 - smoothstep(1.0 - aa, 1.0, UV.y));
		float noise = texture(noise_texture, UV * erode_scale * 0.15 + vec2(0.0, strand)).r;
		float erode = UV.y * 0.7 + UV.x * 0.3;
		erode += sin(UV.x * 23.0 + strand) * 0.10 + noise * 0.12;
		alpha *= smoothstep(stroke_dissolve * 1.4 - erode_sharpness, stroke_dissolve * 1.4 + erode_sharpness, erode + 0.12);
		float heat = UV.y + heat_gain;
		color = mix(edge_color.rgb, body_color.rgb, step(0.12, heat));
		color = mix(color, hot_color.rgb, step(0.55, heat));
		color = mix(color, core_color.rgb, step(0.82, heat));
		if (strand > 0.5) color = mix(body_color.rgb, hot_color.rgb, step(0.65, UV.y));
		float border = min(UV.y, 1.0 - UV.y);
		color = mix(edge_color.rgb, color, smoothstep(edge_width, edge_width + aa, border));
		{
			// Dùng lại nét ngọn lửa của bản đầu, dòng nhiệt chạy trong cùng một dải cong.
			float drift = sin(UV.x * 13.0 - clock * flow_speed * 5.0) * flow_curl;
			vec4 flow = texture(flame_map, vec2(fract(UV.x * 0.8 - clock * flow_speed), clamp(1.0 - UV.y, 0.02, 0.98)));
			float tongue_edge = 0.04 + max(sin(UV.x * tongue_count * 3.141593 - clock * flow_speed * 4.0), 0.0) * tongue_size;
			alpha *= smoothstep(tongue_edge - aa, tongue_edge + aa, UV.y + drift * (1.0 - UV.y));
			float fire_heat = (1.0 - UV.y) * 0.50 + flow.g * 0.75;
			color = mix(edge_color.rgb, body_color.rgb, step(0.20, fire_heat));
			color = mix(color, hot_color.rgb, step(0.52, fire_heat));
			color = mix(color, core_color.rgb, step(0.83, fire_heat));
		}
	}
	if (alpha < 0.01) discard;
	ALBEDO = color;
	ALPHA = alpha * opacity;
}
