shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D storm_painting : source_color, filter_linear_mipmap, repeat_enable;
uniform float exposure : hint_range(0.0, 2.0) = 0.58;
uniform float drift_amount : hint_range(0.0, 0.055) = 0.024;

void vertex() {
	vec2 uv = vec2(fract(UV.x), clamp(UV.y, 0.001, 0.999));
	// Khóa hai cực và đường nối để ảnh mây không bị kéo hở khi nhìn sát mép sân.
	vec2 edge = min(uv, 1.0 - uv);
	float mask = smoothstep(0.025, 0.14, edge.x) * smoothstep(0.025, 0.15, edge.y);
	float flow = TAU * TIME / 50.0;
	vec2 broad = vec2(sin(flow + uv.y * 4.5), 0.38 * sin(flow + uv.x * 6.0));
	vec2 fine = vec2(sin(2.0 * flow + uv.y * 13.0), cos(2.0 * flow - uv.x * 10.0));
	vec2 drift = drift_amount * mask * (broad + 0.22 * fine);
	// Tính độ cuộn trên lưới vòm để mỗi điểm ảnh chỉ cần lấy mẫu ảnh mây một lần.
	UV += drift;
}

void fragment() {
	ALBEDO = texture(storm_painting, UV).rgb * exposure;
}
