shader_type spatial;
// Ngọn lửa bốc lên dọc dải cháy (hạt CPUParticles3D): hình giọt lửa thon nhọn phía trên, mép gợn theo noise,
// lõi sáng ở chân. Quad luôn quay về camera nhưng vẫn giữ cỡ hạt; màu / độ mờ theo COLOR của color_ramp.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.78, 0.30, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.47, 0.065, 1.0);
uniform vec4 outer_color : source_color = vec4(0.84, 0.16, 0.03, 1.0);

uniform sampler2D flame_mask : filter_linear, repeat_disable;
varying float particle_seed;

float hash(float n) {
	return fract(sin(n * 91.7) * 43758.5453);
}

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	particle_seed = hash(float(INSTANCE_ID) + MODEL_MATRIX[3].x * 3.1);
}

void fragment() {
	float rise = 1.0 - UV.y;
	float step_time = floor(TIME * 12.0 + particle_seed * 10.0);
	float lean = sin(step_time * 0.83 + particle_seed * 6.0) * rise * rise * 0.075;
	vec2 brush_uv = vec2(clamp(UV.x - lean, 0.0, 1.0), UV.y);
	// Dùng riêng nửa bên trái của atlas để mỗi ngọn có một thân lửa rõ ở camera xa.
	vec2 atlas_uv = vec2(mix(0.02, 0.465, brush_uv.x), mix(0.04, 0.475, brush_uv.y));
	vec4 stamp = texture(flame_mask, atlas_uv);
	float bend = (0.16 + lean) * rise * rise;
	float width = max(0.035, mix(0.41, 0.035, rise) * smoothstep(-0.12, 0.18, rise));
	float silhouette = 1.0 - smoothstep(width * 0.82, width, abs(UV.x - 0.46 - bend));
	float edge = silhouette * smoothstep(0.0, 0.10, rise) * (1.0 - smoothstep(0.88, 1.0, rise));
	edge *= mix(0.74, 1.0, smoothstep(0.04, 0.55, stamp.a));
	float core = smoothstep(0.56, 0.94, stamp.r) * (1.0 - smoothstep(0.28, 0.84, rise));
	vec3 tint = mix(outer_color.rgb, hot_color.rgb, smoothstep(0.23, 0.69, stamp.r));
	ALBEDO = mix(tint, core_color.rgb, core) * COLOR.rgb;
	ALPHA = edge * COLOR.a;
}
