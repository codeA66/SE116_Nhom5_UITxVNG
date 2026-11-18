shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D cellular_noise : hint_default_white, filter_linear, repeat_enable;
uniform sampler2D crack_mask : hint_default_black, filter_linear, repeat_disable;
uniform vec4 crust_color : source_color = vec4(0.16, 0.045, 0.033, 1.0);
uniform vec4 magma_color : source_color = vec4(0.97, 0.25, 0.045, 1.0);
uniform vec4 seam_color : source_color = vec4(1.0, 0.69, 0.17, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.94, 0.58, 1.0);
uniform float flow_speed : hint_range(0.0, 1.0) = 0.12;
uniform float bubble_cells : hint_range(2.0, 14.0) = 6.0;

uniform float spread : hint_range(0.0, 1.0) = 1.0;
uniform float cooling : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float heat : hint_range(0.0, 1.0) = 0.0;

// Vòng nổ dùng lại shader để các mesh trong pool không chiếm bảng instance uniform của GLES3.
uniform int effect_profile : hint_enum("Dung nham", "Dấu sàn", "Vòng báo") = 0;
uniform sampler2D decal_mask : hint_default_white, filter_linear, repeat_disable;
uniform vec4 decal_color : source_color = vec4(1.0, 0.52, 0.13, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;

float random_cell(vec2 p) {
	return fract(sin(dot(p, vec2(17.63, 91.17))) * 5947.26);
}

vec4 lava_surface(vec2 uv) {
	vec2 axis = uv * 2.0 - 1.0;
	float radius = length(axis);
	float outline = 1.0 - smoothstep(0.98, 1.0, radius);
	if (outline <= 0.0) {
		return vec4(0.0);
	}

	vec2 drift = TIME * flow_speed * vec2(0.35, -0.19);
	float stone = texture(cellular_noise, uv * 1.57 + drift).r;
	float fissures = texture(crack_mask, uv).r;
	float molten_edge = max(spread * 0.99 - 0.38 * cooling, 0.0);
	float front = 1.0 - smoothstep(molten_edge - 0.19, molten_edge + 0.04, radius);
	float liquid = front * (1.0 - cooling * 0.87);
	float plates = smoothstep(0.29, 0.43, stone);
	float veins = max(1.0 - smoothstep(0.022, 0.074, abs(stone - 0.365)), fissures * 0.44);

	// Giữ viền sát thương rõ đến khi vùng đánh tắt dù lớp dung nham bên trong đã nguội.
	float rim = smoothstep(0.82, 0.90, radius);
	float rim_cut = 0.85 + 0.15 * sin(21.0 * atan(axis.y, axis.x + 0.0001) + TIME);
	vec3 glow_color = mix(seam_color.rgb, hot_color.rgb, heat);
	vec3 color = mix(magma_color.rgb, crust_color.rgb, plates * 0.82);
	color = mix(color, glow_color, veins * 0.92);
	color = mix(crust_color.rgb * (0.76 + 0.42 * stone), color, liquid);
	color = mix(color, mix(magma_color.rgb, glow_color, 0.56), rim * rim_cut * (0.9 - cooling * 0.57));

	vec2 grid = uv * bubble_cells;
	float seed = random_cell(floor(grid));
	float bubble_age = fract(TIME * (0.62 + heat * 0.27) + seed);
	float bubble_radius = mix(0.05, 0.28, bubble_age);
	vec2 bubble_offset = vec2(0.37 + 0.23 * seed, 0.40 + 0.13 * seed);
	float bubble_distance = length(fract(grid) - bubble_offset);
	float bubble = 1.0 - smoothstep(0.016, 0.054, abs(bubble_distance - bubble_radius));
	float burst = bubble * (1.0 - smoothstep(0.55, 1.0, bubble_age)) * step(0.37, seed);
	color = mix(color, glow_color, burst * liquid * (1.0 - plates * 0.82) * 0.73);

	return vec4(color, outline * opacity);
}

vec4 ground_decal(vec2 uv) {
	float mask = texture(decal_mask, uv).r;
	if (effect_profile == 2) {
		float r = length(uv * 2.0 - 1.0);
		float fill = progress <= 0.0 ? 0.0 : (1.0 - smoothstep(progress * 0.95 - 0.015, progress * 0.95, r)) * 0.34;
		float outer = smoothstep(0.76, 0.99, mask) * 0.17;
		return vec4(decal_color.rgb, max(fill, outer) * opacity);
	}
	vec3 bright = mix(decal_color.rgb, min(decal_color.rgb * 1.7, vec3(1.0)), mask);
	return vec4(bright, mask * opacity * decal_color.a);
}

void fragment() {
	vec4 result = effect_profile == 0 ? lava_surface(UV) : ground_decal(UV);
	ALBEDO = result.rgb;
	ALPHA = result.a;
}
