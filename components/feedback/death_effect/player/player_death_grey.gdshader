shader_type canvas_item;
// Màn lúc player chết: mọi thứ xám dần trừ vùng tròn quanh nhân vật, viền màn tối nhẹ, cuối cùng tối hẳn.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec2 focus_uv = vec2(0.5);
uniform float focus_radius = 0.1;
uniform float focus_softness = 0.12;
uniform float aspect = 1.7778;
uniform float edge_darkness : hint_range(0.0, 1.0) = 0.45;
// Tối màn cuối cảnh (0 -> 1)
uniform float blackout : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(color, vec3(0.299, 0.587, 0.114));
	// Xám hơi lạnh cho hợp không khí hư không
	vec3 cold = vec3(grey) * vec3(0.92, 0.95, 1.0);
	float dist = length((SCREEN_UV - focus_uv) * vec2(aspect, 1.0));
	float keep = 1.0 - smoothstep(focus_radius, focus_radius + focus_softness, dist);
	color = mix(color, cold, amount * (1.0 - keep));
	float edge = smoothstep(0.35, 0.95, length((SCREEN_UV - vec2(0.5)) * vec2(aspect / 1.7778, 1.0)) * 1.25);
	color *= 1.0 - edge * edge_darkness * amount;
	color *= 1.0 - blackout;
	COLOR = vec4(color, 1.0);
}
