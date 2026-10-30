// Lớp hơi gió mờ (MultiMesh quad quay về camera), rất nhẹ để tạo chiều sâu sau nét gió.
// Vùng gió: các cụm trôi chậm theo hướng gió rồi quay vòng. Cú bung (one_shot): nở ra và tan theo age.
// INSTANCE_CUSTOM: rgb = vị trí trong hộp (0..1, tâm ở 0.5); a = pha / kích thước.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

#include "res://assets/shaders/wind/ambient/wind_flow.gdshaderinc"

uniform vec3 box_size = vec3(4.0, 3.0, 8.0);
uniform vec4 tint : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform float opacity = 0.12;
uniform float puff_size = 2.0;
// Vùng gió: tốc độ trôi (m/s) theo -Z
uniform float drift_speed = 1.5;
// Cú bung: tuổi và thời lượng, quãng nở thêm theo hướng của từng cụm
uniform bool one_shot = false;
uniform float age = 0.0;
uniform float duration = 0.6;
uniform float spread = 1.5;

varying float v_alpha;
varying float v_seed;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	vec3 local = (c.rgb - vec3(0.5)) * box_size;
	float size = puff_size * (0.7 + 0.6 * c.a);
	if (one_shot) {
		float t = clamp(age / max(duration, 0.001), 0.0, 1.0);
		local += normalize(c.rgb - vec3(0.5) + vec3(0.0001)) * spread * (1.0 - pow(1.0 - t, 2.5));
		size *= 0.6 + 0.8 * t;
		v_alpha = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.35, 1.0, t));
	} else {
		float cycle = box_size.z / max(drift_speed, 0.01);
		float p = fract(TIME / cycle + c.a + c.b * 0.37);
		local.z = box_size.z * (0.5 - p);
		v_alpha = wind_coverage(p) * smoothstep(0.0, 0.2, p) * (1.0 - smoothstep(0.75, 1.0, p));
	}
	vec3 view_center = (MODELVIEW_MATRIX * vec4(local, 1.0)).xyz;
	VERTEX = view_center + vec3(VERTEX.xy * size, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_seed = c.a;
}

void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = wind_puff(UV, v_seed, TIME) * tint.a * opacity * v_alpha;
}
