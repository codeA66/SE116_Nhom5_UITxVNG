shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D noise_texture : filter_linear, repeat_enable;
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

varying float kind;
varying float strand;
void vertex() {
	kind = UV2.y;
	strand = UV2.x;
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
		float radius;
		float lift = 0.0;
		if (strand < 0.5) {
			float width = outer * (1.0 - inner_ratio) * taper * mix(1.0 - leading_weight, 1.0, u);
			width *= body_gain;
			
			radius = outer - (1.0 - side) * width;
			lift = sin(u * 3.141593) * depth * (side - 0.5);
		} else {
			float t = u * 6.283185 * curl_turns + strand * 1.7 + clock * curl_speed;
			angle += sin(t) * curl * sin(u * 3.141593);
			float center = outer * (0.88 - strand / max(strand_count, 1.0) * 0.30);
			radius = center + cos(t) * curl * reach * taper;
			radius += (side - 0.5) * secondary_width * reach * taper;
			lift = sin(t) * curl * reach * 0.5;
			float center_angle = (strand / (strand_count + 1.0) - 0.5) * arc_radians * sweep_sign;
			float coil = u * 6.283185 * (1.0 + curl_turns) + clock * curl_speed * 0.2;
			float coil_radius = curl * reach * (1.0 - u * 0.85);
			float center_radius = outer * 0.63;
			radius = center_radius + cos(coil) * coil_radius;
			angle = center_angle + sin(coil) * coil_radius / max(center_radius, 0.001);
			radius += (side - 0.5) * secondary_width * reach * taper;
			lift = sin(coil) * depth;
		}
		p = vec3(sin(angle) * radius, height + lift, cos(angle) * radius);
		p.y += p.x * sin(tilt) * sweep_sign;
	}
	if (clip_box) {
		vec3 half_size = box_size * 0.5;
		p = clamp(p, box_center - half_size, box_center + half_size);
	}
	float r = length(p.xz);
	if (r > outer) p.xz *= outer / max(r, 0.001);
	VERTEX = p * warm_scale;
}
void fragment() {
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
		float head = min((1.0 - pow(1.0 - progress, 3.0)) * 1.05, 1.0);
		alpha = (1.0 - smoothstep(head - aa, head + aa, UV.x));
		alpha *= smoothstep(0.0, aa, UV.y) * (1.0 - smoothstep(1.0 - aa, 1.0, UV.y));
		float noise = texture(noise_texture, UV * erode_scale * 0.15 + vec2(0.0, strand)).r;
		float erode = UV.y * 0.7 + UV.x * 0.3;
		erode += sin(UV.x * 23.0 + strand) * 0.10 + noise * 0.12;
		alpha *= smoothstep(dissolve * 1.4 - erode_sharpness, dissolve * 1.4 + erode_sharpness, erode + 0.12);
		color = mix(body_color.rgb, core_color.rgb, step(0.58, UV.y));
		if (strand > 0.5) color = mix(body_color.rgb, core_color.rgb, step(0.25, UV.y));
		float border = min(UV.y, 1.0 - UV.y);
		color = mix(edge_color.rgb, color, smoothstep(edge_width, edge_width + aa, border));
	}
	if (alpha < 0.01) discard;
	ALBEDO = color;
	ALPHA = alpha * opacity;
}
