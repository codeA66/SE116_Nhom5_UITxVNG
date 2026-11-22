shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Shader riêng cho tổ hợp Phase 2 Slam:
// kind == 0: Vệt chém lửa dọc khổng lồ (Vertical Fire Slash — dựng đứng giống lưỡi liềm Rear Slash).
// kind == 1: Vết nứt dọc trên tường & cổng không gian lửa (Spatial Rift Portal).
// kind == 2: Sợi xích rèn lửa bọc ngọn lửa xoắn bắn ra từ cổng không gian (hỗ trợ tan biến thành tro khi trượt).
// kind == 3: Vòng xích lửa xoắn trói quanh thân player trong 2 giây.
uniform int kind = 0;
uniform float age = 0.0;
uniform float open_t = 1.0;
uniform float fade_t = 0.0;
uniform float chain_len = 1.0;

varying vec2 v_uv;
varying vec4 v_col;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 41.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	v += 0.54 * vnoise(p);
	v += 0.30 * vnoise(p * 2.13 + vec2(11.7, 5.3));
	v += 0.16 * vnoise(p * 4.41 - vec2(4.1, 19.2));
	return v;
}

void vertex() {
	v_uv = UV;
	v_col = COLOR;
	if (kind == 2 && v_col.a > 0.5) {
		// Vỏ lửa cuộn xoắn quanh sợi xích (mesh sheath đánh dấu COLOR.a > 0.5).
		float along = UV.y * max(chain_len, 1.0);
		float flutter = sin(along * 4.5 - TIME * 18.0 + COLOR.r * 6.2831) * 0.065;
		VERTEX += NORMAL * flutter;
	}
}

void fragment() {
	vec2 p = v_uv * 2.0 - 1.0;
	vec3 dark_void = vec3(0.03, 0.01, 0.04);
	vec3 crimson = vec3(0.84, 0.04, 0.08);
	vec3 hot_orange = vec3(1.0, 0.36, 0.04);
	vec3 bright_gold = vec3(1.0, 0.80, 0.18);
	vec3 white_hot = vec3(1.0, 0.97, 0.84);

	vec3 color = hot_orange;
	float opacity = 0.0;
	float boost = 1.25;

	if (kind == 0) {
		// Vệt chém lửa nằm dọc (trục Y là chiều cao lưỡi liềm, trục X là chiều hướng bay: +1 phía mũi chém -> -1 phía đuôi lửa).
		float y_ratio = clamp(abs(p.y) / 0.96, 0.0, 1.0);
		float horn_taper = pow(1.0 - y_ratio * y_ratio, 0.78);
		float front = 0.84 - p.y * p.y * 1.15;
		float back_dist = front - p.x;

		float flow = fbm(vec2(back_dist * 3.0 - TIME * 6.5, p.y * 4.2));
		float ribbon = 0.5 + 0.5 * sin((p.y * 7.5 - back_dist * 4.8) + flow * 3.8 - TIME * 9.5);
		float tail_len = 1.25 * horn_taper * (0.68 + 0.36 * flow + 0.20 * ribbon);

		float leading = smoothstep(-0.04, 0.045, back_dist);
		float body = leading * (1.0 - smoothstep(tail_len * 0.45, max(0.06, tail_len), back_dist));
		float edge_core = leading * (1.0 - smoothstep(0.04, max(0.07, 0.28 * horn_taper), back_dist));
		float tail_zone = smoothstep(0.24 * horn_taper, max(0.26, tail_len * 0.92), back_dist);
		float wisp_cut = smoothstep(0.20, 0.72, flow * 0.60 + ribbon * 0.40);
		float shaped = body * mix(1.0, wisp_cut, tail_zone * 0.65);

		opacity = clamp(shaped * (1.0 - smoothstep(0.75, 1.0, fade_t)), 0.0, 1.0);
		color = mix(crimson, hot_orange, smoothstep(0.0, 0.72, 1.0 - tail_zone));
		color = mix(color, bright_gold, edge_core * 0.95);
		color = mix(color, white_hot, pow(edge_core, 2.0) * 0.88);
		boost = mix(1.25, 1.95, edge_core);
	} else if (kind == 1) {
		// Vết nứt dọc trên tường & cổng không gian lửa (open_t: 0 -> 1 mở rộng, 1 -> 0 khép lại).
		float op = clamp(open_t, 0.0, 1.0);
		float n_rift = fbm(vec2(p.x * 4.8, p.y * 4.2 - TIME * 3.8));
		float n_fine = vnoise(vec2(p.x * 11.0 + TIME * 2.5, p.y * 9.5 - TIME * 5.2));
		float y_env = pow(max(0.0, 1.0 - p.y * p.y), 0.65);
		float sway = (n_rift - 0.5) * 0.14 * y_env;
		float dx = abs(p.x - sway);

		// Vết nứt đá đen cháy ăn sâu hai bên cổng trên mặt tường.
		float crack_w = (0.04 + 0.09 * n_fine) * y_env;
		float wall_crack = (1.0 - smoothstep(crack_w, crack_w + 0.08, dx)) * smoothstep(0.02, 0.20, op);
		// Các nhánh rạn ngang nhỏ tỏa ra khỏi vết chém dọc.
		float branch_wave = sin(p.y * 14.0 + n_rift * 4.0);
		float side_crack = (1.0 - smoothstep(0.02, 0.07, abs(branch_wave))) * (1.0 - smoothstep(0.10, 0.58 * y_env, dx)) * smoothstep(0.15, 0.45, op);

		// Khe cổng không gian rộng dần khi op tăng: lõi tím-đen xoáy lửa + viền lửa rực cam-đỏ-vàng.
		float slit_w = mix(0.02, 0.34, op) * y_env;
		float void_core = 1.0 - smoothstep(max(0.008, slit_w * 0.55), max(0.015, slit_w), dx);
		float fire_rim = (1.0 - smoothstep(0.01, 0.16 + 0.08 * op, abs(dx - slit_w))) * y_env;
		float fire_licks = pow(max(0.0, n_rift * 0.65 + n_fine * 0.35), 1.4) * (1.0 - smoothstep(slit_w, slit_w + 0.32 * op, dx)) * y_env;
		// Xoáy năng lượng lửa bên trong lòng cổng.
		float swirl = fbm(vec2(p.x * 6.0 / max(0.15, slit_w), p.y * 5.5 - TIME * 7.2));
		float inner_fire = void_core * smoothstep(0.32, 0.82, swirl) * op;

		float shape = max(max(void_core, max(fire_rim, fire_licks * 0.90)), max(wall_crack * 0.92, side_crack * 0.65));
		opacity = clamp(shape * smoothstep(0.0, 0.12, op), 0.0, 1.0);

		color = mix(vec3(0.08, 0.06, 0.06), crimson, clamp(fire_licks + side_crack * 0.85, 0.0, 1.0));
		color = mix(color, hot_orange, clamp(fire_rim * 0.95 + inner_fire * 0.85, 0.0, 1.0));
		color = mix(color, bright_gold, clamp(pow(fire_rim, 1.7) * 0.95 + pow(inner_fire, 1.6) * 0.8, 0.0, 1.0));
		color = mix(color, white_hot, pow(fire_rim, 3.0) * 0.72);
		color = mix(color, dark_void, void_core * (1.0 - inner_fire * 0.82) * 0.92);
		boost = mix(1.05, 2.05, max(fire_rim, inner_fire * 0.85));
	} else if (kind == 2) {
		// Sợi xích lửa: COLOR.a < 0.5 = mắt xích kim loại nóng đỏ; COLOR.a >= 0.5 = vỏ lửa xoắn cháy bao bọc quanh xích.
		float along = v_uv.y * max(chain_len, 1.0);
		float n_burn = fbm(vec2(v_uv.x * 5.0, along * 1.6 - TIME * 7.5));
		float dissolve = 1.0 - smoothstep(fade_t * 1.15 - 0.18, fade_t * 1.15 + 0.12, n_burn);
		if (fade_t > 0.01 && dissolve > 0.92) { discard; }
		float ash_edge = fade_t > 0.01 ? smoothstep(0.45, 0.92, dissolve) : 0.0;

		if (v_col.a < 0.5) {
			// Mắt xích 3D phân đốt sáng rực theo nhịp link_uv (mỗi 0.42m một mắt xích).
			float link_phase = fract(along * 2.35);
			float joint = abs(link_phase - 0.5) * 2.0;
			float link_glow = 1.0 - smoothstep(0.18, 0.68, joint);
			float iron_edge = smoothstep(0.45, 0.92, abs(p.x));
			vec3 iron = mix(vec3(0.12, 0.06, 0.06), vec3(0.42, 0.12, 0.06), iron_edge);
			color = mix(iron, crimson, 0.55 + link_glow * 0.35);
			color = mix(color, hot_orange, link_glow * 0.88 + n_burn * 0.25);
			color = mix(color, bright_gold, pow(link_glow, 2.0) * 0.85 + ash_edge);
			opacity = (1.0 - smoothstep(0.75, 1.0, fade_t));
			boost = mix(1.20, 1.95, max(link_glow, ash_edge));
		} else {
			// Vỏ lửa cuộn xoắn bọc quanh thân sợi xích.
			float spiral = 0.5 + 0.5 * sin(along * 6.5 + v_uv.x * 12.566 - TIME * 15.0);
			float sheath = smoothstep(0.24, 0.78, n_burn * 0.62 + spiral * 0.38);
			float x_soft = 1.0 - smoothstep(0.45, 0.98, abs(p.x));
			opacity = clamp(sheath * x_soft * 0.88 * (1.0 - smoothstep(0.65, 1.0, fade_t)), 0.0, 0.92);
			color = mix(crimson, hot_orange, smoothstep(0.20, 0.72, sheath));
			color = mix(color, bright_gold, smoothstep(0.65, 0.96, sheath));
			boost = 1.65;
		}
	} else {
		// kind == 3: Vòng xích lửa xoắn trói chặt quanh người player (2 giây).
		float angle_u = v_uv.x * 6.0;
		float n_b = fbm(vec2(angle_u * 2.2 - TIME * 4.5, v_uv.y * 5.0));
		float links = 0.5 + 0.5 * sin(angle_u * 6.2831853);
		float band = 1.0 - smoothstep(0.32, 0.92, abs(p.y));
		float fade = (1.0 - smoothstep(0.70, 1.0, fade_t)) * smoothstep(0.0, 0.08, open_t);
		opacity = clamp(band * (0.68 + 0.32 * links) * fade, 0.0, 0.96);
		color = mix(vec3(0.16, 0.05, 0.05), crimson, 0.55 + n_b * 0.45);
		color = mix(color, hot_orange, links * 0.85);
		color = mix(color, bright_gold, pow(links, 2.2) * 0.90);
		boost = mix(1.30, 1.95, links);
	}

	ALBEDO = color * boost;
	EMISSION = color * (0.45 + (boost - 1.0) * 0.88);
	ALPHA = opacity;
}
