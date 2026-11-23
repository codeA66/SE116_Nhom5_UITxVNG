uniform vec2 radial_limits = vec2(0.12, 1.42);
uniform bool returning = false;
uniform float breakup : hint_range(0.0, 1.0) = 0.0;
uniform float visibility_weight : hint_range(0.0, 1.0) = 1.0;
uniform float body_width : hint_range(0.10, 0.72) = 0.63;
uniform float edge_radius : hint_range(0.65, 1.18) = 1.06;
uniform float tip_inset : hint_range(0.0, 0.3) = 0.13;
uniform float brush_edge : hint_range(0.0, 0.09) = 0.064;
uniform float strand_spacing : hint_range(0.02, 0.18) = 0.084;
uniform float strand_width : hint_range(0.003, 0.035) = 0.014;
uniform float split_start : hint_range(0.05, 0.5) = 0.19;
uniform float split_full : hint_range(0.25, 0.75) = 0.46;

float snap_band(float r, float center, float width, float aa) {
	return 1.0 - smoothstep(width, width + aa, abs(r - center));
}

float snap_belly(float t) {
	float weight = smoothstep(0.035, 0.31, t);
	float draw_off = 1.0 - smoothstep(0.29, 0.97, t);
	return weight * draw_off;
}

float snap_contour(float t, float belly) {
	return edge_radius - tip_inset * (1.0 - belly) + 0.15 * smoothstep(0.57, 1.0, t);
}

float snap_fiber(float r, float t, float center, float start, float end, float drift, float width, float aa) {
	float lengthwise = clamp((t - start) / max(end - start, 0.001), 0.0, 1.0);
	float taper = smoothstep(0.0, 0.24, lengthwise) * (1.0 - smoothstep(0.32, 1.0, lengthwise));
	float path = center + drift * lengthwise;
	return snap_band(r, path, width * taper, aa) * taper;
}

// Thân teo về mép ngoài trước khi tách, để cung không biến thành một vệt mờ đều.
vec4 snap_shape(vec2 uv) {
	float t = returning ? 1.0 - uv.x : uv.x;
	float r = mix(radial_limits.x, radial_limits.y, uv.y);
	float aa = clamp(fwidth(r), 0.0015, 0.030);
	float life = 1.0 - smoothstep(0.66, 1.0, breakup);
	float belly = snap_belly(t);
	float sweep_edge = snap_contour(t, belly);
	float split = smoothstep(split_start, max(split_full, split_start + 0.001), breakup);
	float width = body_width * belly * (1.0 - split * 0.90);
	float nib = brush_edge * belly * (1.0 - split);
	float outer_edge = sweep_edge + nib * (0.30 * sin(t * 47.0) + 0.22 * sin(t * 122.0 + 0.8));
	float inner_edge = sweep_edge - width + nib * (0.52 * sin(t * 53.0) + 0.22 * sin(t * 139.0));
	float body = smoothstep(-aa, aa, min(r - inner_edge, outer_edge - r));
	body *= smoothstep(0.003, 0.036, width) * (1.0 - smoothstep(0.17, 0.59, breakup));
	float across = clamp((r - inner_edge) / max(width, 0.001), 0.0, 1.0);

	// Rãnh đi xuyên qua mép theo chiều chém để phần đuôi rách thành những mũi độc lập.
	float outer_cut = snap_fiber(r, t, sweep_edge - 0.063, 0.28, 0.56, 0.116, 0.051, aa);
	float inner_cut = snap_fiber(r, t, sweep_edge - 0.405, 0.43, 0.71, 0.155, 0.034, aa);
	float tail_cut = snap_fiber(r, t, sweep_edge - 0.082, 0.72, 0.93, 0.064, 0.016, aa);
	body *= 1.0 - max(max(outer_cut * 0.78, inner_cut * 0.84), tail_cut * 0.74) * (1.0 - split);

	// So le điểm rút của các sợi để còn vài nét nhỏ ở cuối thay vì cả vòng sáng.
	float sweep = smoothstep(0.044, 0.23, t) * (1.0 - smoothstep(0.93, 1.0, t));
	float contracted = smoothstep(0.46, 0.94, breakup);
	float taper = pow(max(belly, 0.0), 0.65);
	float line_one = snap_band(r, sweep_edge - 0.008, strand_width * (1.80 * taper + 0.21), aa);
	line_one *= mix(sweep, smoothstep(0.21, 0.42, t) * (1.0 - smoothstep(0.83, 0.99, t)), contracted);
	float arc_two = sweep_edge - strand_spacing * (0.42 + 1.14 * belly) - 0.022 * sin(t * 7.0);
	float line_two = snap_band(r, arc_two, strand_width * (1.05 * taper + 0.08), aa);
	line_two *= smoothstep(0.10, 0.26, t) * (1.0 - smoothstep(0.52, 0.80, t));
	line_two *= 1.0 - smoothstep(0.48, 0.76, breakup);
	float arc_three = sweep_edge - strand_spacing * (1.12 + 1.85 * belly) + 0.036 * sin(t * 11.0);
	float line_three = snap_band(r, arc_three, strand_width * (0.97 * taper + 0.11), aa);
	line_three *= smoothstep(0.17, 0.32, t) * (1.0 - smoothstep(0.53, 0.70, t));
	line_three *= 1.0 - smoothstep(0.47, 0.67, breakup);

	float carry = breakup * 0.07;
	// Chung mép với thân trước khi trượt ra ngoài, để các nét phụ nối được hướng vung kiếm.
	float wisp = snap_fiber(r, t, sweep_edge - 0.053, 0.46 + carry, 1.0, 0.091, 0.030, aa);
	float first_tip = snap_fiber(r, t, sweep_edge - 0.023, 0.65 + carry, 0.96, 0.126, 0.019, aa);
	float second_tip = snap_fiber(r, t, sweep_edge + 0.042, 0.79 + carry, 0.995, 0.102, 0.013, aa);
	float start_wisp = snap_fiber(r, t, sweep_edge + 0.082, 0.005, 0.35, -0.093, 0.017, aa);
	float lines = max(max(line_one, line_two * 0.81), line_three * 0.65) * split;
	float tips = max(max(first_tip * 0.76, second_tip * 0.51), start_wisp * 0.50);
	lines = max(lines, max(wisp, tips) * (1.0 - smoothstep(0.29, 0.83, breakup)));
	float color_rake = snap_fiber(r, t, inner_edge + width * 0.33, 0.15, 0.76, 0.12, 0.060, aa);
	return vec4(body * life, lines * life, across, color_rake);
}
