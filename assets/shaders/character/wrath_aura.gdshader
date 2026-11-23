shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform vec4 ink_color : source_color = vec4(0.47, 0.12, 0.19, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.94, 0.83, 1.0);
uniform vec4 accent_color : source_color = vec4(0.94, 0.33, 0.27, 1.0);
uniform int surface_kind = 5;
uniform float age = 0.0;
uniform float strength = 0.0;
uniform float envelope = 0.0;
uniform float radius = 0.78;
uniform float center_height = 0.62;
uniform float rise = 1.35;
uniform float stroke_width = 0.42;
uniform float arc_span = 0.36;
uniform float spin_speed = 0.55;
uniform float pulse_phase = 0.0;
uniform float pulse_radius_ratio = 1.8;
varying vec4 particle_tint;

float ink_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	float a = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(cell + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(cell + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(cell + vec2(1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
}

void vertex() {
	particle_tint = COLOR;
	if (surface_kind == 1 || surface_kind == 4) {
		float r = radius * (surface_kind == 1 ? mix(0.4, pulse_radius_ratio, pulse_phase) : 1.3);
		VERTEX = vec3((UV.x - 0.5) * r * 2.0, 0.035, (UV.y - 0.5) * r * 2.0);
	} else {
		// Mặt phẳng hướng camera giữ khí mềm ở góc nhìn cao, không cần thêm mesh bao thân.
		float scale_value = surface_kind == 5 ? mix(0.7, 1.0, envelope) : length(MODEL_MATRIX[0].xyz);
		vec3 origin = MODEL_MATRIX[3].xyz;
		if (surface_kind == 5) {
			origin.y += center_height;
		}
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(origin, 1.0));
		if (surface_kind == 5) {
			VERTEX = vec3((UV.x - 0.5) * radius * 2.6, (0.5 - UV.y) * rise * 1.3, 0.0) * scale_value;
		} else if (surface_kind == 6) {
			VERTEX = vec3((UV.x - 0.5) * 2.0, (0.5 - UV.y) * 2.0, 0.0) * scale_value;
		} else {
			VERTEX *= scale_value;
		}
	}
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float d = length(p);
	float mask = 0.0;
	vec3 paint = ink_color.rgb;
	if (surface_kind == 2) {
		mask = 1.0 - smoothstep(0.05, 0.95, dot(p, p));
		paint = mix(accent_color.rgb, edge_color.rgb, exp(-dot(p, p) * 7.0));
	} else if (surface_kind == 1) {
		float softness = clamp(stroke_width / max(radius, 0.001), 0.1, 0.7);
		float swell = (1.0 - smoothstep(0.3, 0.95, d)) * smoothstep(0.0, softness, d);
		mask = swell * pow(1.0 - pulse_phase, 1.8) * 0.8;
		paint = mix(accent_color.rgb, edge_color.rgb, max(0.0, 0.35 - pulse_phase));
	} else if (surface_kind == 4) {
		float cloud = ink_noise(UV * 4.0 + vec2(age * spin_speed, -age * spin_speed));
		mask = (1.0 - smoothstep(0.1, 0.95, d)) * cloud * envelope;
	} else if (surface_kind == 5) {
		vec2 flow = vec2(sin(age * 0.8) * 0.2, age * spin_speed * 1.6);
		float broad = ink_noise(UV * vec2(3.5, 4.5) + flow);
		float fine = ink_noise(UV * vec2(8.0, 11.0) + flow * 1.4);
		p.x += (broad - 0.5) * 0.22;
		p.y += (fine - 0.5) * 0.10;
		float edge = length(p);
		float outside = 1.0 - smoothstep(0.45, 0.98, edge);
		// Tâm loãng giữ rõ mặt cáo; biên tan bằng hai lớp nhiễu thay cho nét slash.
		float center_clear = smoothstep(0.12, 0.53, edge);
		float density = smoothstep(0.15, 0.7, broad * 0.7 + fine * 0.3);
		mask = outside * center_clear * density * envelope * 0.9;
		paint = mix(ink_color.rgb, accent_color.rgb, smoothstep(0.25, 0.8, fine));
	} else if (surface_kind == 6) {
		float brush = ink_noise(UV * (4.0 + arc_span * 3.0) + vec2(sin(age) * 0.1, age * spin_speed));
		p.x += (brush - 0.5) * 0.35;
		float body = 1.0 - smoothstep(0.05, 1.0, dot(p, p));
		mask = body * smoothstep(0.1, 0.75, brush) * 0.6;
		paint = mix(ink_color.rgb * 0.65, accent_color.rgb, brush * 0.6);
	}
	ALBEDO = paint;
	ALPHA = mask * strength * particle_tint.a;
}
