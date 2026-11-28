shader_type spatial;
render_mode cull_back;

// Shader phản chiếu phẳng cho gương đồng (dùng SubViewport ViewportTexture).
// GHI CHÚ TỐI ƯU: Có thể thay hoặc pha thêm phản chiếu giả lập (cubemap / gradient)
// ở nhánh này trong tương lai nếu cần giảm số SubViewport thời gian thực.

uniform sampler2D reflection_tex : source_color, filter_linear, repeat_disable;
uniform vec3 mirror_local_axis = vec3(0.0, 1.0, 0.0);
uniform float mirror_radius = 0.86;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.82;
uniform vec4 tint_color : source_color = vec4(0.86, 0.72, 0.46, 1.0);
uniform vec4 base_color : source_color = vec4(0.42, 0.31, 0.18, 1.0);
uniform vec4 edge_color : source_color = vec4(0.5, 0.25, 0.085, 1.0);
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.6;
uniform float fresnel_boost : hint_range(0.0, 1.0) = 0.28;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.85;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.22;
uniform bool flip_y = false;

varying vec3 v_local_normal;
varying vec3 v_local_pos;

void vertex() {
	v_local_normal = normalize(NORMAL);
	v_local_pos = VERTEX;
}

void fragment() {
	vec3 axis = length(mirror_local_axis) > 0.001 ? normalize(mirror_local_axis) : vec3(0.0, 1.0, 0.0);
	// Phân biệt mặt phẳng gương với vành hông mảnh để không tạo thêm mesh chồng gây z-fighting.
	float face_mask = step(0.7, abs(dot(normalize(v_local_normal), axis)));

	if (face_mask > 0.5) {
		float diameter = max(mirror_radius * 2.0, 0.01);
		float face_sign = v_local_normal.y >= 0.0 ? -1.0 : 1.0;
		float u = clamp(0.5 + face_sign * (v_local_pos.x / diameter), 0.0, 1.0);
		float v = clamp(0.5 + (v_local_pos.z / diameter), 0.0, 1.0);
		vec2 mirror_uv = vec2(u, flip_y ? (1.0 - v) : v);
		vec3 refl = texture(reflection_tex, mirror_uv).rgb * tint_color.rgb;
		float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		float fresnel = pow(1.0 - ndotv, fresnel_power);
		float weight = clamp(reflection_strength + fresnel * fresnel_boost, 0.0, 1.0);

		ALBEDO = base_color.rgb;
		METALLIC = metallic_value;
		ROUGHNESS = roughness_value;
		EMISSION = refl * weight;
	} else {
		ALBEDO = edge_color.rgb;
		METALLIC = 0.65;
		ROUGHNESS = 0.45;
		EMISSION = vec3(0.0);
	}
}
