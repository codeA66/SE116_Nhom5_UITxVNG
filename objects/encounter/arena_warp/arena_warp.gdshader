// Phễu gió hút dưới sàn (QuadMesh ngang). Sàn che mất mesh lõm thật nên giả chiều sâu: bắn tia từ camera xuyên
// mặt quad, dò qua LEVELS tầng phễu (mỗi tầng hẹp dần, tối dần); tầng đầu tiên tia ra ngoài bán kính = chạm thành
// phễu, tô nét xoáy của tầng đó (mỗi tầng quay nhanh hơn). Tia lọt hết = lõi tối. Đổi góc camera thì thành phễu
// trượt đúng kiểu thị sai, nhìn ra cái hố chứ không phải hình dán.
// appear 0..1 mở / co phễu; flash chớp sáng lúc player bước vào. Không đọc màn hình (renderer Compatibility).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.6, 0.88, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.01, 0.015, 0.03, 1.0);
uniform float intensity = 1.8;
// Bán kính miệng phễu (m), script đặt bằng radius của ArenaWarp
uniform float radius = 1.6;
// Độ sâu giả của phễu (m)
uniform float depth = 2.4;
// Đáy phễu hẹp còn bao nhiêu so với miệng
uniform float bottom_ratio = 0.15;
uniform float appear = 1.0;
uniform float spin_speed = 0.8;
uniform float arms = 3.0;
uniform float twist = 1.6;
uniform float rim_width = 0.05;
uniform float flash = 0.0;

const int LEVELS = 7;

varying vec3 local_pos;
varying vec3 local_cam;

void vertex() {
	local_pos = VERTEX;
	local_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

float swirl(vec2 q, float r_norm, float level) {
	float ang = atan(q.y, q.x);
	float s = sin(ang * arms + r_norm * twist * 6.2832 - TIME * spin_speed * (1.0 + level * 0.5) * 3.0 + level * 1.7);
	return smoothstep(0.55, 1.0, s);
}

void fragment() {
	float mouth = radius * max(appear, 0.001);
	vec2 top = local_pos.xz;
	float rt = length(top) / mouth;
	if (rt > 1.0) {
		discard;
	}
	vec3 dir = normalize(local_pos - local_cam);
	vec3 glow = tint.rgb * intensity;
	vec3 col = core_color.rgb;
	for (int i = 1; i <= LEVELS; i++) {
		float f = float(i) / float(LEVELS);
		float t = depth * f / max(-dir.y, 0.05);
		vec2 q = top + dir.xz * t;
		float level_radius = mouth * mix(1.0, bottom_ratio, f);
		if (length(q) > level_radius) {
			// Thành phễu: càng sâu càng tối, nét xoáy là các dải gió cuộn xuống
			float shade = pow(1.0 - f, 1.3);
			float s = swirl(q, length(q) / mouth, float(i));
			col = mix(core_color.rgb, glow, (0.18 + 0.82 * s) * shade);
			break;
		}
	}
	float rim = exp(-pow((rt - (1.0 - rim_width)) / rim_width, 2.0));
	col = mix(col, glow, rim);
	col += glow * flash;
	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(0.96, 1.0, rt);
}
