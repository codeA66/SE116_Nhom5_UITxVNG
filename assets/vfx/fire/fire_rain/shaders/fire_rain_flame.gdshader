shader_type spatial;
// Ngọn lửa bốc lên ở cụm lửa (hạt CPUParticles3D): dáng giọt lửa bầu tròn ở chân, thon nhọn lên đỉnh, mép gợn và
// đỉnh lắc theo noise chạy liên tục (không nhảy bậc: bậc thời gian làm lửa giật cục ở camera xa).
// Lõi vàng sáng ở chân, cam ở thân, đỏ ở mép / đỉnh. Quad luôn quay về camera; màu / độ mờ nhân COLOR của color_ramp.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.94, 0.67, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.66, 0.16, 1.0);
uniform vec4 outer_color : source_color = vec4(0.9, 0.24, 0.035, 1.0);
// Độ bầu của chân lửa (bán kính, theo nửa bề ngang quad) và chiều cao phần bầu
uniform float bulb_width = 0.62;
uniform float bulb_height = 0.3;
uniform float flicker_speed = 7.0;
uniform float sway = 0.32;

varying float particle_seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	particle_seed = hash(MODEL_MATRIX[3].xz * 3.7 + vec2(float(INSTANCE_ID), 1.0));
}

void fragment() {
	// y: 0 ở chân, 1 ở đỉnh
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float t = TIME * flicker_speed + particle_seed * 17.0;
	// Càng lên cao lắc càng mạnh
	float lean = (noise(vec2(p.y * 2.2 - t * 0.55, particle_seed * 9.0)) - 0.5) * sway * p.y;
	float x = p.x - lean;
	float base = sqrt(clamp(p.y / bulb_height, 0.0, 1.0));
	float top = pow(1.0 - clamp((p.y - bulb_height * 0.8) / (1.0 - bulb_height * 0.8), 0.0, 1.0), 1.15);
	float profile = bulb_width * base * top;
	// Mép gợn: lưỡi lửa liếm lên
	profile *= 0.82 + 0.36 * noise(vec2(p.y * 5.5 - t * 1.4, x * 2.5 + particle_seed * 5.0));
	float d = abs(x) / max(profile, 0.001);
	float body = (1.0 - smoothstep(0.78, 1.0, d)) * step(0.0, p.y) * (1.0 - smoothstep(0.92, 1.0, p.y));
	float hot = (1.0 - smoothstep(0.35, 0.95, d)) * (1.0 - p.y * 0.55);
	float core = (1.0 - smoothstep(0.2, 0.62, d)) * (1.0 - smoothstep(0.12, 0.5, p.y));
	vec3 color = mix(outer_color.rgb, hot_color.rgb, clamp(hot * 1.4, 0.0, 1.0));
	color = mix(color, core_color.rgb, core);
	ALBEDO = color * COLOR.rgb;
	ALPHA = body * COLOR.a;
}
