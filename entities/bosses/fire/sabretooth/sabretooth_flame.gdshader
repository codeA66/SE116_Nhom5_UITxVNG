shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform int form = 2;
uniform float rise_origin = 0.0;
uniform float rise_height = 0.0;
uniform bool transitioning = false;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform bool portal_clip = false;
uniform vec3 portal_origin = vec3(0.0);
uniform vec3 portal_normal = vec3(0.0, 1.0, 0.0);
uniform float reform : hint_range(0.0, 1.0) = 1.0;
uniform bool reverting_top_down = false;
uniform float revert_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 revert_head_pos = vec3(0.0, 1.4, 1.0);
uniform float revert_top_y = 2.0;

varying vec3 local_point;
varying vec3 world_point;

// Alpha của vertex dùng để nhận diện dải lửa vẽ chung với thân.
bool is_wisp(float marker) {
	return marker > 0.965 && marker < 0.995;
}

bool is_ivory(float marker) {
	return marker > 0.955 && marker < 0.965;
}

float noise3(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 key = dot(cell, vec3(127.1, 311.7, 74.7)) + vec4(0.0, 127.1, 311.7, 438.8);
	vec4 low = fract(sin(key) * 43758.5453);
	vec4 high = fract(sin(key + 74.7) * 43758.5453);
	vec4 layer = mix(low, high, f.z);
	return mix(mix(layer.x, layer.y, f.x), mix(layer.z, layer.w, f.x), f.y);
}

void vertex() {
	if (form == 2 && is_ivory(COLOR.a)) {
		// Gốc rig ở điểm chạm đất. Giữ mũi móng trên sàn khi ngón gập sâu.
		VERTEX.y = max(VERTEX.y, 0.006);
	} else if (form == 2 && is_wisp(COLOR.a)) {
		float tip = UV.y * UV.y;
		float flutter = sin(TIME * 4.0 + COLOR.b * 13.0 - UV.y * 3.1);
		VERTEX.x += flutter * tip * 0.028;
		VERTEX.y += sin(TIME * 4.4 + COLOR.b * 11.0) * tip * 0.021;
	}
	local_point = VERTEX;
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Ba đuôi dùng mesh riêng để đổi tư thế từ cùng một gốc đuôi.
	if (form == 2 && COLOR.a < 0.955) { discard; }
	float edge = 0.0;
	float dissolve_edge = 0.0;
	float portal_edge = 0.0;
	if (portal_clip) {
		float plane_d = dot(world_point - portal_origin, normalize(portal_normal));
		if (plane_d < 0.0) { discard; }
		portal_edge = 1.0 - smoothstep(0.0, 0.30, plane_d);
	}
	if (reform < 0.999 && form >= 2) {
		// Flame Reformation: mắt & nanh lóe sáng trước -> khung silhouette rìa lửa -> đặc khối toàn thân.
		float r_rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.7);
		float r_n = noise3(local_point * 2.8 - vec3(0.0, TIME * 2.2, 0.0));
		if (form == 3) {
			if (reform < 0.18) { discard; }
			edge = max(edge, 1.0 - smoothstep(0.18, 0.48, reform));
		} else if (is_ivory(COLOR.a)) {
			if (reform < 0.26) { discard; }
			edge = max(edge, 1.0 - smoothstep(0.26, 0.56, reform));
		} else {
			float solid_t = smoothstep(0.42, 0.96, reform);
			float outline_band = r_rim * 0.72 + r_n * 0.35;
			float threshold = mix(0.88, -0.05, solid_t);
			if (reform < 0.24 || outline_band < threshold) { discard; }
			edge = max(edge, (1.0 - smoothstep(0.0, 0.24, outline_band - threshold)) * (1.0 - solid_t * 0.7));
		}
	}
	if (reverting_top_down) {
		// Tan biến hiệu ứng lửa Phase 2 từ đỉnh đầu & tai quét xuống vai/thân/chân (kể cả khi đang đổ ngã gục xuống sàn!).
		float ragged_r = noise3(world_point * vec3(3.8, 3.2, 3.8) - vec3(0.0, TIME * 2.5, 0.0));
		float h_norm = clamp((world_point.y - rise_origin) / max(revert_top_y, 0.65), 0.0, 1.0);
		float head_prox = 1.0 - clamp(length(world_point - revert_head_pos) / 3.4, 0.0, 1.0);
		float top_rank = clamp(h_norm * 0.56 + head_prox * 0.44, 0.0, 1.0);
		float rev_cut = 1.14 - revert_progress * 1.32 + (ragged_r - 0.5) * 0.22;
		float rev_front = rev_cut - top_rank;
		if ((form < 2 && rev_front > 0.04) || (form >= 2 && rev_front < 0.0)) {
			discard;
		}
		edge = max(edge, 1.0 - smoothstep(0.0, 0.22, abs(rev_front)));
	} else if (transitioning) {
		float ragged = noise3(world_point * vec3(4.0, 3.0, 4.0) - vec3(0.0, TIME * 2.8, 0.0));
		float front = world_point.y - rise_origin - rise_height + (ragged - 0.5) * 0.48;
		if ((form < 2 && front < 0.0) || (form >= 2 && front > 0.085)) {
			discard;
		}
		edge = 1.0 - smoothstep(0.0, 0.29, abs(front));
	}
	if (dissolve > 0.0) {
		vec3 bands = local_point * vec3(2.6, 0.95, 3.0);
		float rank = clamp(noise3(bands) * 0.55 + local_point.y * 0.17, 0.03, 0.96);
		float front = rank - dissolve;
		if (front < 0.0) { discard; }
		dissolve_edge = (1.0 - smoothstep(0.02, 0.16, front)) * smoothstep(0.0, 0.16, dissolve);
	}

	if (form < 2) {
		ALBEDO = COLOR.rgb;
		EMISSION = (form == 1 ? COLOR.rgb * 0.65 : vec3(0.0)) + vec3(1.2, 0.18, 0.022) * edge;
	} else if (form == 3) {
		ALBEDO = vec3(0.16, 0.14, 0.06);
		EMISSION = vec3(2.55, 2.12, 0.79);
	} else if (is_wisp(COLOR.a)) {
		float travel = UV.y;
		float phase = TIME * 3.9 + COLOR.b * 17.0;
		float side = sign(COLOR.g - 0.5);
		float bend = travel * (-0.16 + 0.43 * travel + 0.11 * sin(phase - travel * 5.0));
		float across = (UV.x * 2.0 - 1.0) * side - bend;
		float width = mix(0.92, 0.008, travel * travel) * (0.12 + 0.88 * smoothstep(0.0, 0.30, travel));
		float notch = smoothstep(0.28, 0.65, travel) * (1.0 - smoothstep(0.69, 1.0, travel));
		float outer = width - across;
		float inner = across + width * (1.0 - notch * 0.59);
		if (min(outer, inner) < 0.0) {
			discard;
		}
		float head = smoothstep(0.23, 0.89, travel);
		float drift = 0.88 + 0.12 * sin(phase - travel * 9.0 + across * 3.5);
		float amber_rank = (1.0 - smoothstep(0.09, 0.70, outer)) * drift;
		float rim = 1.0 - smoothstep(0.015, 0.23, outer);
		float hot = rim * head * drift;
		vec3 ember = mix(vec3(0.198, 0.021, 0.012), vec3(0.74, 0.099, 0.018), smoothstep(0.13, 0.68, travel));
		vec3 flame = mix(ember, vec3(1.0, 0.34, 0.055), amber_rank * smoothstep(0.09, 0.46, travel));
		flame = mix(flame, vec3(1.0, 0.74, 0.25), hot);
		flame = mix(flame, vec3(1.0, 0.90, 0.62), 0.48 * hot * smoothstep(0.74, 1.0, travel));
		ALBEDO = flame * 0.18;
		EMISSION = flame * (0.81 + hot * 0.43 + edge * 0.42);
	} else {
		bool amber_detail = is_ivory(COLOR.a);
		// Thu nhỏ vân lửa trên nanh và móng để đọc được ở góc camera chơi.
		vec3 flow = local_point * vec3(2.8, 1.55, 3.0);
		flow *= amber_detail ? 2.5 : 1.0;
		flow.y -= TIME * 1.55;
		float curl = noise3(flow * 0.65 + vec3(0.0, 0.0, TIME * 0.16));
		flow.xz += vec2(1.75, 1.3) * curl;
		float body = noise3(flow);
		float stream = sin(flow.y * 2.0 + flow.x * 2.9 + flow.z * 2.2 + body * 5.5);
		float ribbon = smoothstep(0.21, 0.84, stream) * smoothstep(0.26, 0.73, body);
		float filament = smoothstep(0.77, 1.0, stream) * smoothstep(0.45, 0.79, body);
		float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.1);
		float base_heat = amber_detail ? 0.25 : COLOR.r * 0.82;
		float heat = clamp(base_heat + ribbon * 0.43 + filament * 0.31 + rim * 0.31 + edge * 0.67, 0.0, 1.0);
		vec3 red = mix(vec3(0.19, 0.018, 0.014), vec3(0.77, 0.092, 0.022), smoothstep(0.0, 0.61, heat));
		vec3 flame = mix(red, vec3(1.0, 0.39, 0.085), smoothstep(0.40, 1.0, heat));
		float emission_strength = mix(0.78, 1.11, heat);
		if (amber_detail) {
			vec3 amber = mix(vec3(0.63, 0.22, 0.030), vec3(1.0, 0.47, 0.095), smoothstep(0.22, 0.64, heat));
			flame = mix(amber, vec3(1.0, 0.73, 0.28), smoothstep(0.48, 0.94, heat));
			emission_strength = mix(0.91, 1.16, heat) + rim * 0.10;
		}
		ALBEDO = flame * 0.26;
		EMISSION = flame * emission_strength;
		// Kênh xanh của mặt quanh mắt lưu vùng bắt sáng theo rig.
		if (COLOR.r < 0.27 && COLOR.g < 0.1) {
			EMISSION += vec3(0.63, 0.42, 0.18) * COLOR.b;
		}
	}
	EMISSION += vec3(1.45, 0.44, 0.075) * dissolve_edge + vec3(1.85, 0.68, 0.12) * portal_edge;
	ROUGHNESS = 0.9;
}
