shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.88,0.82,0.66,1);
uniform vec4 ink : source_color = vec4(0.03,0.045,0.055,0.7);
uniform vec4 hot : source_color = vec4(0.95,0.92,0.85,1);
uniform float fill_ratio = 0.0;
uniform float wave_height = 0.025;
uniform float wave_speed = 4.0;
uniform float wave_frequency = 8.0;
uniform float idle_wave = 0.18;
uniform float clock = 0.0;
uniform float activity = 0.0;
uniform float flash = 0.0;
uniform float slosh = 0.0;
uniform float rise_glint = 0.0;
uniform float flow_progress = 1.0;
uniform float flow_direction = 0.0;
uniform float facet_strength = 0.0;
uniform bool masked = false;
uniform sampler2D mask_texture : filter_linear;

float flow_motes(vec2 uv, float surface) {
	if (flow_progress >= 1.0 || abs(flow_direction) < 0.5) {
		return 0.0;
	}
	float motes = 0.0;
	float rising = step(0.0, flow_direction);
	// Phân nhịp để hạt đi cùng mực nước, tránh chớp đồng loạt.
	for (int i = 0; i < 5; i++) {
		if (i >= 3 && rising < 0.5) {
			break;
		}
		float index = float(i);
		float t = clamp((flow_progress - index * 0.058) / (0.72 - index * 0.036), 0.0, 1.0);
		float visibility = smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.61, 1.0, t));
		float lane = 0.24 + fract(index * 0.618) * 0.54;
		float depth = mix(0.035 + 0.20 * t, 0.025 + 0.27 * (1.0 - t), rising);
		vec2 center = vec2(lane + sin(t * 5.0 + index) * 0.025, surface + depth);
		float radius = mix(0.018, 0.040, fract(index * 0.43 + 0.69)) * (1.0 - 0.30 * t);
		float dist = length((uv - center) * vec2(1.0, 0.91));
		float edge = 1.0 - smoothstep(radius * 0.64, radius, dist);
		motes = max(motes, edge * visibility);
	}
	return motes;
}

void fragment() {
	vec2 p = UV*2.0-1.0;
	float circle = 1.0-smoothstep(0.965,1.0,length(p));
	float fill = clamp(fill_ratio,0.0,1.0);
	float phase = TIME*wave_speed+clock*0.2;
	float wave = sin(UV.x*wave_frequency+phase)*0.72+sin(UV.x*wave_frequency*1.65-phase*0.8)*0.28;
	float boundary = smoothstep(0.0,0.08,fill)*(1.0-smoothstep(0.92,1.0,fill));
	float surface = 1.0-fill+(wave*wave_height*mix(idle_wave,1.0,activity)+p.x*slosh*0.092)*boundary;
	float liquid = smoothstep(surface-0.007,surface+0.007,UV.y)*step(0.0001,fill);
	float depth_px = max(0.0, UV.y - surface);
	float depth = clamp(depth_px / max(1.0 - surface, 0.001), 0.0, 1.0);
	float lip = (1.0 - smoothstep(0.022, 0.052, depth_px)) * liquid * boundary;
	float shoulder = (1.0 - smoothstep(0.035, 0.22, depth_px)) * liquid * boundary;
	// Giữ mép sáng trên mặt mực để thấy ngay phần vừa tiêu.
	vec3 fluid = mix(tint.rgb * 0.77, mix(tint.rgb, hot.rgb, 0.53), 1.0 - depth * 0.68);
	float soft_reflection = 1.0 - smoothstep(0.06, 0.40, length((UV - vec2(0.31, 0.28)) * vec2(1.1, 0.86)));
	fluid = mix(fluid, hot.rgb, soft_reflection * facet_strength);
	vec3 cavity = mix(ink.rgb * 0.60, ink.rgb * 1.65, soft_reflection);
	vec3 color = mix(cavity, fluid, liquid);
	float glint = lip * 0.73 + shoulder * (0.13 + rise_glint * 0.22);
	color = mix(color, hot.rgb, clamp(glint + flash * 0.12 * liquid, 0.0, 1.0));
	color = mix(color, hot.rgb, flow_motes(UV, clamp(surface, 0.08, 0.93)) * liquid * 0.83);
	float alpha = circle * mix(max(ink.a, 0.96), 1.0, liquid);
	if (masked) alpha *= texture(mask_texture,UV).a;
	COLOR = vec4(color,alpha);
}
