shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

// Pha lấy cùng mã với AbilityAcquireRenderer để shader chạy theo nhịp FSM.
// Ngôn ngữ hình theo cảnh nhận phép của Hollow Knight: chỉ có đốm sáng tròn đổi trạng thái qua từng pha
// (bốc lên ở bệ → nổ ra phủ màn hình → bị hút thành vệt về ngực → cụm sáng → quầng sáng mềm bùng ra).
const int IDLE = -1;
const int LIFT = 0;
const int ABSORB = 1;
const int BURST = 2;
const int SETTLE = 3;
const int SCATTER = 4;
const float GOLDEN_TURN = 2.399963;
const float TAU_F = 6.283185;
const float DERIVATIVE_STEP = 0.01;

uniform vec4 core_color : source_color = vec4(1.0);
uniform float intensity = 0.0;
uniform float wisp_count = 18.0;
uniform vec2 column_radius = vec2(0.34, 0.79);
uniform float column_height = 2.45;
uniform float wisp_width = 0.095;
uniform float wisp_span = 0.88;
uniform float spin_speed = 0.92;
uniform float mote_total = 150.0;
uniform float mote_size = 0.12;
uniform float mote_rise_speed = 0.14;
uniform vec2 scatter_spread = vec2(7.5, 4.4);
uniform float scatter_depth = 1.5;
uniform float foreground_ratio = 0.12;
uniform float foreground_depth = 4.0;
uniform float foreground_scale = 2.6;
uniform float explode_portion = 0.32;
uniform float wander_amplitude = 0.35;
uniform float wander_speed = 0.7;
uniform float absorb_delay = 0.5;
uniform float absorb_span = 0.36;
uniform float cluster_radius = 0.55;
uniform float absorb_streak = 1.3;
uniform float burst_streak = 7.0;
uniform float streak_max = 1.6;
uniform float burst_radius = 4.5;
uniform float settle_ratio = 0.25;
uniform float settle_rise = 1.6;
uniform float orb_radius = 1.2;
uniform float orb_burst_scale = 2.2;
uniform float orb_camera_offset = 0.85;
uniform int phase;
uniform float phase_progress = 0.0;
uniform vec3 chest = vec3(0.0);
uniform vec3 source = vec3(0.0, 0.6, 0.0);

varying flat float kind;
varying flat float seed;
varying flat float opacity;

float variation(float n) {
	return fract(sin(n * 12.9898 + 1.17) * 43758.5453);
}

float eased(float t) {
	return t * t * (3.0 - 2.0 * t);
}

float release_motion(float p) {
	return 1.0 - pow(1.0 - p, 2.6);
}

// Cột gió lúc chờ: trải đều cao độ để các vệt gối lên nhau mà không đồng loạt sinh rồi tắt.
vec3 idle_point(float id, float u) {
	float level = (id + 0.5) / wisp_count;
	float angle = id * GOLDEN_TURN + TIME * spin_speed + wisp_span * (u - 0.5);
	float radius = mix(column_radius.x, column_radius.y, variation(id));
	float height = column_height * level + sin(TIME * spin_speed + id * GOLDEN_TURN) * 0.12;
	return vec3(cos(angle) * radius, height + u * radius * 0.25, sin(angle) * radius);
}

// Đốm lúc chờ bốc lên trong cột; Lift gom về chỗ sách tan nên Scatter nổ ra đúng từ nguồn.
vec3 column_mote(float id) {
	float angle = id * GOLDEN_TURN + TIME * spin_speed * 0.6;
	float radius = mix(column_radius.x, column_radius.y, variation(id + 1.0)) * 0.8;
	float height = fract(variation(id + 2.0) + TIME * mote_rise_speed) * column_height;
	return vec3(cos(angle) * radius, height, sin(angle) * radius);
}

vec3 lift_end(float id) {
	vec3 jitter = vec3(variation(id + 3.0), variation(id + 4.0), variation(id + 5.0)) - 0.5;
	return source + jitter * 0.5;
}

// Đích Scatter đặt trong mặt phẳng camera để mây đốm phủ khung hình bất kể góc nhìn.
vec3 scatter_target(float id, vec3 right, vec3 up, vec3 toward) {
	float x = (variation(id + 6.0) * 2.0 - 1.0) * scatter_spread.x;
	float y = (variation(id + 7.0) * 2.0 - 1.0) * scatter_spread.y;
	float depth = (variation(id + 8.0) * 2.0 - 1.0) * scatter_depth;
	if (variation(id + 9.0) < foreground_ratio) {
		depth = foreground_depth * (0.6 + variation(id + 10.0) * 0.4);
	}
	return chest + right * x + up * y + toward * depth;
}

vec3 wander(float id, vec3 right, vec3 up) {
	float a = TIME * wander_speed + variation(id + 11.0) * TAU_F;
	float b = TIME * wander_speed * 0.8 + variation(id + 12.0) * TAU_F;
	return (right * sin(a) + up * cos(b)) * wander_amplitude;
}

vec3 scatter_point(float id, float p, vec3 right, vec3 up, vec3 toward) {
	float burst = clamp(p / explode_portion, 0.0, 1.0);
	float spread = 1.0 - pow(1.0 - burst, 3.0);
	return mix(lift_end(id), scatter_target(id, right, up, toward), spread) + wander(id, right, up) * spread;
}

vec3 cluster_point(float id, vec3 right, vec3 up, vec3 toward) {
	vec3 offset = right * (variation(id + 13.0) - 0.5) + up * (variation(id + 14.0) - 0.5) + toward * (variation(id + 15.0) - 0.5);
	float shimmer = 1.0 + sin(TIME * 7.0 + id * GOLDEN_TURN) * 0.15;
	return chest + offset * 2.0 * cluster_radius * shimmer;
}

float absorb_pull(float id, float p) {
	float t = clamp((p - variation(id + 16.0) * absorb_delay) / absorb_span, 0.0, 1.0);
	// Tăng tốc dần (ease-in) để đốm kéo dài thành vệt khi lao vào ngực.
	return t * t * t;
}

vec3 burst_point(float id, float p, vec3 right, vec3 up) {
	vec3 direction = normalize(right * (variation(id + 17.0) * 2.0 - 1.0) + up * (variation(id + 18.0) * 2.0 - 1.0) + vec3(0.0, 0.3, 0.0));
	return cluster_point(id, right, up, vec3(0.0)) + direction * burst_radius * (0.45 + variation(id + 19.0) * 0.55) * release_motion(p);
}

vec3 settle_point(float id, float p) {
	vec3 offset = vec3(variation(id + 20.0) - 0.5, 0.0, variation(id + 21.0) - 0.5) * 1.2;
	return chest + offset + vec3(0.0, settle_rise * p * (0.5 + variation(id + 22.0)), 0.0);
}

vec3 mote_point(float id, float p, vec3 right, vec3 up, vec3 toward) {
	if (phase == IDLE) {
		return column_mote(id);
	}
	if (phase == LIFT) {
		return mix(column_mote(id), lift_end(id), eased(p));
	}
	if (phase == SCATTER) {
		return scatter_point(id, p, right, up, toward);
	}
	if (phase == ABSORB) {
		return mix(scatter_point(id, 1.0, right, up, toward), cluster_point(id, right, up, toward), absorb_pull(id, p));
	}
	if (phase == BURST) {
		return burst_point(id, p, right, up);
	}
	return settle_point(id, p);
}

float mote_opacity(float id, float p) {
	float twinkle = 0.75 + sin(TIME * 3.8 + id * GOLDEN_TURN) * 0.25;
	if (phase == IDLE) {
		return intensity * 0.5 * twinkle;
	}
	if (phase == LIFT) {
		return mix(intensity * 0.5, 1.0, eased(p)) * twinkle;
	}
	if (phase == SCATTER) {
		return twinkle;
	}
	if (phase == ABSORB) {
		// Cụm sáng tan vào quầng sáng khi quả cầu đã đủ lớn.
		return mix(twinkle, 1.0, absorb_pull(id, p)) * (1.0 - smoothstep(0.88, 0.98, p));
	}
	if (phase == BURST) {
		return smoothstep(0.0, 0.06, p) * (1.0 - p);
	}
	return variation(id + 23.0) < settle_ratio ? (1.0 - p) * smoothstep(0.0, 0.15, p) * 0.8 : 0.0;
}

float streak_gain() {
	if (phase == ABSORB) {
		return absorb_streak;
	}
	if (phase == BURST) {
		return burst_streak;
	}
	return 0.0;
}

// Lõi chỉ hiện khi đốm đầu tiên tới, nén lại một nhịp trước khi bùng (anticipation).
float orb_scale(float p) {
	if (phase == ABSORB) {
		return smoothstep(0.55, 0.88, p) * mix(1.0, 0.75, smoothstep(0.9, 1.0, p));
	}
	if (phase == BURST) {
		return 0.75 + release_motion(p) * orb_burst_scale;
	}
	if (phase == SETTLE) {
		return 0.75 + orb_burst_scale + p * 0.4;
	}
	return 0.0;
}

float orb_opacity(float p) {
	if (phase == ABSORB) {
		return smoothstep(0.55, 0.8, p);
	}
	if (phase == BURST) {
		return 1.0 - p * 0.25;
	}
	if (phase == SETTLE) {
		return 0.75 * (1.0 - smoothstep(0.0, 0.45, p));
	}
	return 0.0;
}

void vertex() {
	kind = UV2.y;
	seed = UV2.x;
	opacity = 0.0;
	float p = clamp(phase_progress, 0.0, 1.0);
	mat3 to_local = inverse(mat3(MODEL_MATRIX));
	vec3 right = normalize(to_local * INV_VIEW_MATRIX[0].xyz);
	vec3 up = normalize(to_local * INV_VIEW_MATRIX[1].xyz);
	vec3 toward = normalize(to_local * INV_VIEW_MATRIX[2].xyz);
	if (kind < 0.5) {
		// Dải gió chỉ thuộc cột chờ; tan hết trong Lift để lúc nghi thức chỉ còn một loại hình.
		if (phase == IDLE) {
			opacity = intensity;
		} else if (phase == LIFT) {
			opacity = intensity * (1.0 - eased(p));
		}
		float u = UV.x;
		vec3 center = idle_point(seed, u);
		float delta = u < 0.95 ? 0.04 : -0.04;
		vec3 tangent = (idle_point(seed, u + delta) - center) * sign(delta);
		vec2 projected = vec2(-dot(tangent, up), dot(tangent, right));
		projected /= max(length(projected), 0.0001);
		float width = wisp_width * mix(0.20, 1.0, sin(u * PI * 0.85)) * (0.60 + variation(seed) * 0.65);
		// Dải đã tắt thì gom về một điểm để không tốn fill.
		width *= step(0.001, opacity);
		VERTEX = center + (right * projected.x + up * projected.y) * (UV.y - 0.5) * width;
		opacity *= 0.58 + variation(seed + 9.0) * 0.42;
	} else if (kind > 2.5) {
		vec3 center = mote_point(seed, p, right, up, toward);
		opacity = mote_opacity(seed, p);
		float size = mote_size * (0.45 + variation(seed + 24.0) * 1.1);
		if (variation(seed + 9.0) < foreground_ratio && (phase == SCATTER || phase == ABSORB)) {
			size *= foreground_scale;
		}
		// Vệt theo vận tốc trên màn hình: đốm đứng yên thì tròn, lao nhanh thì dài ra.
		vec3 ahead = mote_point(seed, min(p + DERIVATIVE_STEP, 1.0), right, up, toward) - center;
		vec2 screen = vec2(dot(ahead, right), dot(ahead, up));
		float speed = length(screen);
		vec2 axis = speed > 0.0001 ? screen / speed : vec2(1.0, 0.0);
		float stretch = min(speed * streak_gain(), streak_max);
		vec2 corner = (UV - 0.5);
		vec2 along = axis * corner.x * (size + stretch);
		vec2 across = vec2(-axis.y, axis.x) * corner.y * size;
		vec2 offset = along + across;
		VERTEX = center + right * offset.x + up * offset.y;
	} else {
		float radius = orb_radius * orb_scale(p);
		opacity = orb_opacity(p);
		vec3 center = chest + toward * orb_camera_offset;
		VERTEX = center + (right * (UV.x - 0.5) + up * (UV.y - 0.5)) * (radius * 2.0);
	}
}

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float radius = length(point);
	float coverage;
	if (kind < 0.5) {
		float edge = abs(UV.y * 2.0 - 1.0);
		coverage = (1.0 - smoothstep(0.74, 1.0, edge)) * smoothstep(0.0, 0.28, UV.x) * (1.0 - smoothstep(0.90, 1.0, UV.x));
	} else if (kind > 2.5) {
		// Lõi đặc + quầng mờ: đọc như đốm sáng mềm, không phải chấm phẳng.
		float core = 1.0 - smoothstep(0.22, 0.5, radius);
		float halo = (1.0 - smoothstep(0.3, 1.0, radius)) * 0.45;
		coverage = max(core, halo);
	} else {
		// Quầng sáng dạng gauss, không có viền cứng; lõi đặc nhỏ để thân cáo tan trong ánh sáng.
		float glow = exp(-radius * radius * 4.5);
		float core = 1.0 - smoothstep(0.0, 0.32, radius);
		coverage = max(core, glow) * (1.0 - smoothstep(0.85, 1.0, radius));
	}
	if (coverage * opacity < 0.008) {
		discard;
	}
	ALBEDO = core_color.rgb;
	ALPHA = coverage * opacity;
}
