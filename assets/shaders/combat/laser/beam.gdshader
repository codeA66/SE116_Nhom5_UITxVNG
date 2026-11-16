shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, skip_vertex_transform;

uniform vec4 core_color : source_color = vec4(1.0, 0.86, 0.9, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.07, 0.23, 1.0);
uniform vec4 warn_color : source_color = vec4(1.0, 0.18, 0.30, 1.0);
uniform sampler2D noise_strip : repeat_enable, filter_linear;
uniform float core_fraction : hint_range(0.03, 0.5) = 0.2;
uniform float intensity : hint_range(0.0, 2.0) = 1.12;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.56;
uniform float scroll_speed : hint_range(0.0, 12.0) = 2.5;
uniform float noise_scale : hint_range(0.05, 4.0) = 0.46;
uniform float width_flicker : hint_range(0.0, 0.3) = 0.075;
uniform float flicker_speed : hint_range(0.0, 20.0) = 7.0;
uniform float dash_spacing : hint_range(0.05, 4.0) = 0.65;
uniform float dash_fill : hint_range(0.15, 0.85) = 0.55;
uniform float warn_min_intensity : hint_range(0.0, 1.0) = 0.24;
uniform float warn_max_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float warn_pulse_depth : hint_range(0.0, 1.0) = 0.32;

instance uniform float ray_length = 1.0;
instance uniform float ray_width = 0.4;
instance uniform float envelope = 1.0;
instance uniform float warn_progress = 0.0;
instance uniform float warn_blink_rate = 10.0;
instance uniform float flicker_offset = 0.0;
instance uniform bool warning = false;

void vertex() {
	vec3 center = (MODELVIEW_MATRIX * vec4(0.0, 0.0, VERTEX.y * ray_length, 1.0)).xyz;
	vec3 axis = normalize(MODELVIEW_MATRIX[2].xyz);
	vec3 across = cross(axis, -MODELVIEW_MATRIX[3].xyz);
	if (dot(across, across) < 0.00001) {
		across = MODELVIEW_MATRIX[0].xyz;
	}
	float flicker = sin(TIME * flicker_speed + flicker_offset) * width_flicker;
	VERTEX = center + normalize(across) * VERTEX.x * ray_width * (1.0 + flicker) * envelope;
}

void fragment() {
	float edge = abs(UV.x * 2.0 - 1.0);
	float aa = max(fwidth(edge), 0.005);
	if (warning) {
		float cells = max(2.0, round(ray_length / dash_spacing));
		float tick = abs(fract(UV.y * cells) - 0.5) * 2.0;
		float dash_aa = min(fwidth(tick), 0.25);
		float dash = 1.0 - smoothstep(dash_fill - dash_aa, dash_fill + dash_aa, tick);
		float pulse = warn_blink_rate > 0.0 ?
			1.0 - warn_pulse_depth * (0.5 + 0.5 * sin(TIME * TAU * warn_blink_rate + flicker_offset)) : 1.0;
		float charge = mix(warn_min_intensity, warn_max_intensity, warn_progress);
		ALBEDO = warn_color.rgb;
		ALPHA = (1.0 - smoothstep(0.08, 1.0, edge)) * dash * pulse * charge * warn_color.a;
	} else {
		float drift = UV.y * ray_length * noise_scale - TIME * scroll_speed;
		float flow = texture(noise_strip, vec2(drift, 0.5)).r;
		float core = 1.0 - smoothstep(max(0.0, core_fraction - aa), core_fraction + aa, edge);
		float halo = pow(max(0.0, 1.0 - edge), 1.8);
		ALBEDO = mix(glow_color.rgb, core_color.rgb, core);
		ALPHA = max(core * intensity * core_color.a,
			halo * glow_intensity * glow_color.a * mix(0.58, 1.0, flow)) * envelope;
	}
}
