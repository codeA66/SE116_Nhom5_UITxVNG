shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D wind_noise : repeat_enable, filter_linear;
uniform vec4 wind_color : source_color = vec4(0.72, 0.93, 0.91, 0.65);
uniform vec4 highlight_color : source_color = vec4(0.96, 1.0, 0.94, 0.9);
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform float age = 0.0;
uniform float flow_speed = 2.3;
uniform vec2 noise_scale = vec2(2.6, 1.5);
uniform float band_count = 5.0;
uniform float swirl = 0.35;
uniform float edge_softness = 0.16;

void fragment() {
    float n = texture(wind_noise, vec2(UV.x * noise_scale.x - age * flow_speed, UV.y * noise_scale.y)).r;
    float wave = sin((UV.y * band_count + UV.x * swirl - age * 0.7 + n * 0.17) * TAU);
    float brush = smoothstep(0.05, 0.9, wave);
    float ends = smoothstep(0.0, edge_softness, UV.x) * (1.0 - smoothstep(0.60, 1.0, UV.x));
    float breakup = 0.35 + 0.65 * smoothstep(0.15, 0.72, n);
    ALBEDO = mix(wind_color.rgb, highlight_color.rgb, brush * 0.7);
    ALPHA = opacity * ends * (0.06 + brush * breakup) * wind_color.a;
}
