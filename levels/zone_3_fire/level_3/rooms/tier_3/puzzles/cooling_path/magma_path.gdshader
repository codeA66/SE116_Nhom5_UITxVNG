shader_type spatial;
render_mode unshaded;

uniform vec4 surface_color : source_color = vec4(1.0, 0.25, 0.04, 1.0);
uniform bool hot = true;
uniform bool warning = false;
uniform float warning_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 transition_color : source_color = vec4(1.0, 0.22, 0.035, 1.0);
uniform float glow_strength : hint_range(0.0, 4.0) = 1.2;
uniform float vein_scale : hint_range(0.1, 5.0) = 1.4;
uniform float vein_width : hint_range(0.01, 0.2) = 0.06;

varying vec3 world_position;
varying float face_shade;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Giữ màu đá nguội xám dưới ánh sáng cam của Map Lửa.
	face_shade = mix(0.6, 1.0, abs(NORMAL.y));
}

void fragment() {
	float progress = clamp(warning_progress, 0.0, 1.0);
	float heat = hot ? 1.0 : (warning ? mix(0.0, 0.85, progress) : 0.0);
	vec3 stone_color = warning ? mix(surface_color.rgb, transition_color.rgb, progress) : surface_color.rgb;
	// Tính gân theo thế giới để các module có tỉ lệ khác nhau vẫn nối cùng mật độ.
	vec2 p = world_position.xz / max(vein_scale, 0.01);
	vec2 warp = vec2(sin(p.y * 2.3), sin(p.x * 1.7)) * 0.2;
	vec2 cell = abs(fract(p + warp) - vec2(0.5));
	float vein = 1.0 - smoothstep(vein_width, vein_width * 1.8, min(cell.x, cell.y));
	float detail = clamp(dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722)) * 2.5 + 0.5, 0.5, 1.0);
	float crust = mix(1.0, mix(0.3, 1.0, vein), heat);
	ALBEDO = stone_color * detail * crust * face_shade;
	ALBEDO += stone_color * glow_strength * heat * mix(0.05, 1.0, vein);
}
